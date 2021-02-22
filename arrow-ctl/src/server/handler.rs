use super::super::message::*;
use super::models::*;
use super::Webserver;
use futures::{StreamExt,FutureExt};
use serde::{Deserialize, Serialize};
use serde_json::from_str;
use tokio::sync::mpsc;
use tokio_stream::wrappers::UnboundedReceiverStream;
use uuid::Uuid;
use warp::reply::json;
use warp::ws::{WebSocket, Ws};

use log::{trace, debug, error, info};

type Result<T> = std::result::Result<T, warp::Rejection>;

#[derive(Serialize, Deserialize)]
pub struct MeasureRequest {
    n: u64,
}

/*
pub async fn new_measure(body: MeasureRequest) -> Result<impl warp::Reply, warp::Rejection> {
    Ok("ok")
}
*/

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

    client.sender = Some(client_sender);
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
        handle_ws_message(&id, msg).await;
    }

    clients.sockets.write().await.remove(&id);
    info!(target: "arrow::web::ws", "{} disconnected", id);
}

pub async fn handle_ws_message(_id: &String, msg: warp::ws::Message) {
    debug!(target: "arrow::web::ws", "received message '{:#?}'",  msg);
    let message: WSMessage = match msg.to_str() {
        Ok(m) => match from_str(m) {
            Ok(m) => m,
            Err(e) => {
                error!(target: "arrow::web::ws", "error parsing message '{}'", e);
                return;
            }
        },
        Err(_) => {
            error!(target: "arrow::web::ws", "error parsing message '{:#?}'", msg);
            return;
        }
    };
    match message {
    };
}
