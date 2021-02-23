use super::super::message::*;
use super::super::models::*;
use super::Webserver;

use futures::{FutureExt, StreamExt};
use serde_json::from_str;
use uuid::Uuid;

use warp::reply::json;
use warp::ws::{WebSocket, Ws};

use log::{debug, error, info, trace};

use std::collections::HashMap;
use std::convert::TryFrom;
use std::sync::Arc;

use tokio::sync::mpsc;
use tokio::sync::RwLock;
use tokio_stream::wrappers::UnboundedReceiverStream;

#[derive(Debug, thiserror::Error)]
pub enum WSError {
    #[error(transparent)]
    Sql(#[from] sqlx::Error),

    #[error("bad request: {0}.")]
    Logic(String),
}

#[derive(Clone, Debug)]
pub struct WSocket {
    pub sender: Option<mpsc::UnboundedSender<std::result::Result<warp::ws::Message, warp::Error>>>,
}

pub type Clients = Arc<RwLock<HashMap<String, WSocket>>>;

type Result<T> = std::result::Result<T, warp::Rejection>;

pub async fn new_client(srv: Webserver) -> Result<impl warp::Reply> {
    let uuid = Uuid::new_v4().simple().to_string();
    let response = WSRegisterResponse {
        url: format!("/ws/{}", uuid),
    };
    srv.sockets
        .write()
        .await
        .insert(uuid, WSocket { sender: None });
    trace!("sockets: {:#?}", srv.sockets.read().await);
    Ok(json(&response))
}

pub async fn delete_client(srv: Webserver, id: String) -> Result<impl warp::Reply> {
    trace!("deleting client: {}", id);
    srv.sockets.write().await.remove(&id);
    Ok(warp::http::StatusCode::OK)
}

pub async fn ws_connect(srv: Webserver, ws: Ws, id: String) -> Result<impl warp::Reply> {
    trace!("trying to connect: {}", id);
    let client = srv.sockets.read().await.get(&id).cloned();
    match client {
        Some(c) => Ok(ws.on_upgrade(move |socket| client_connection(socket, id, srv, c))),
        None => Err(warp::reject::not_found()),
    }
}

async fn client_connection(ws: WebSocket, id: String, clients: Webserver, mut client: WSocket) {
    let (client_ws_sender, mut client_ws_rcv) = ws.split();
    let (client_sender, client_rcv) = mpsc::unbounded_channel();

    let client_rx = UnboundedReceiverStream::new(client_rcv);
    tokio::task::spawn(client_rx.forward(client_ws_sender).map(|result| {
        if let Err(e) = result {
            error!(target: "arrow::web::ws", "error sending websocket message: {}", e);
        }
    }));

    client.sender = Some(client_sender.clone());
    clients.sockets.write().await.insert(id.clone(), client);

    info!(target: "arrow::web::ws", "{} connected", id);

    while let Some(result) = client_ws_rcv.next().await {
        let msg = match result {
            Ok(msg) => msg,
            Err(e) => {
                error!(target: "arrow::web::ws", "error receiving ws message for id: {}): {}", id.clone(), e);
                break;
            }
        };
        handle_ws_message(&id, msg, clients.clone(), client_sender.clone()).await;
    }

    clients.sockets.write().await.remove(&id);
    info!(target: "arrow::web::ws", "{} disconnected", id);
}

pub async fn handle_ws_message(
    _id: &String,
    msg: warp::ws::Message,
    srv: Webserver,
    response_channel: mpsc::UnboundedSender<std::result::Result<warp::ws::Message, warp::Error>>,
) {
    debug!(target: "arrow::web::ws", "received message '{:#?}'",  msg);
    let message = match WSMessage::try_from(msg) {
        Ok(m) => m,
        Err(e) => {
            let err = format!("error parsing message '{}'", e);
            error!(target: "arrow::web::ws", "error parsing message '{}'", e);
            let _ = response_channel
                .send(Ok(WSMessage::Response(WSUpdate::Error(err)).into()))
                .map_err(|e| {
                    error!(target: "arrow::server::ws", "Cannot send response to client: {}", e);
                });
            return;
        }
    };
    if let WSMessage::Request(request) = message {
        let response = match request {
            WSRequest::ListBows {} => list_bows(srv).await,
            WSRequest::AddBow(bow) => add_bow(srv, bow).await,
            WSRequest::NewMeasureSeries(series) => add_measure_series(srv, series).await,
        };

        let msg: warp::ws::Message = WSMessage::Response(match response {
            Ok(r) => r,
            Err(e) => {
                let err = format!("Error while executing Request: {}", e);
                WSUpdate::Error(err)
            }
        })
        .into();
        let _ = response_channel.send(Ok(msg)).map_err(|e| {
            error!(target: "arrow::server::ws", "Cannot send response to client: {}", e);
        });
    }
}

async fn list_bows(srv: Webserver) -> std::result::Result<WSUpdate, WSError> {
    let bows = sqlx::query_as!(Bow, "SELECT * FROM bow")
        .fetch_all(&srv.db_pool)
        .await?;

    Ok(WSUpdate::BowList(bows))
}

async fn add_bow(srv: Webserver, bow: Bow) -> std::result::Result<WSUpdate, WSError> {
    let rec = sqlx::query!(
        r#"INSERT INTO bow 
        (name, max_draw_distance, remainder_arrow_length)
        VALUES ($1, $2, $3)
        RETURNING id"#,
        bow.name,
        bow.max_draw_distance,
        bow.remainder_arrow_length
    )
    .fetch_one(&srv.db_pool)
    .await?;
    Ok(WSUpdate::BowList(vec![Bow { id: rec.id, ..bow }]))
}

async fn add_measure_series(
    srv: Webserver,
    series: MeasureSeries,
) -> std::result::Result<WSUpdate, WSError> {
    if series.draw_distance.is_none() && series.draw_force.is_none() {
        return Err(WSError::Logic(
            "either draw_distance or draw_force must be set".into(),
        ));
    }
    let rec = sqlx::query!(
        r#"INSERT INTO measure_series 
        (name, rest_position, draw_distance, draw_force, time, bow_id)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id"#,
        series.name,
        series.rest_position,
        series.draw_distance,
        series.draw_force,
        series.time,
        series.bow_id,
    )
    .fetch_one(&srv.db_pool)
    .await?;
    Ok(WSUpdate::MeasureSeriesList(vec![MeasureSeries {
        id: rec.id,
        ..series
    }]))
}
