use super::super::message::*;
use super::super::models::*;
use super::database::ArrowDB;
use super::Webserver;

use futures::{FutureExt, StreamExt};
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

pub async fn new_client(srv: Webserver<impl ArrowDB>) -> Result<impl warp::Reply> {
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

pub async fn delete_client<F: ArrowDB>(srv: Webserver<F>, id: String) -> Result<impl warp::Reply> {
    trace!("deleting client: {}", id);
    srv.sockets.write().await.remove(&id);
    Ok(warp::http::StatusCode::OK)
}

pub async fn ws_connect<F: ArrowDB + 'static>(
    srv: Webserver<F>,
    ws: Ws,
    id: String,
) -> Result<impl warp::Reply> {
    trace!("trying to connect: {}", id);
    let client = srv.sockets.read().await.get(&id).cloned();
    match client {
        Some(c) => Ok(ws.on_upgrade(move |socket| client_connection(socket, id, srv, c))),
        None => Err(warp::reject::not_found()),
    }
}

async fn client_connection<F: ArrowDB>(
    ws: WebSocket,
    id: String,
    clients: Webserver<F>,
    mut client: WSocket,
) {
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
        handle_ws_message(&id, msg, &clients, client_sender.clone()).await;
    }

    clients.sockets.write().await.remove(&id);
    info!(target: "arrow::web::ws", "{} disconnected", id);
}

pub async fn handle_ws_message<F: ArrowDB>(
    _id: &String,
    msg: warp::ws::Message,
    srv: &Webserver<F>,
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
            WSRequest::AddArrow(arrow) => add_arrow(srv, arrow).await,
            WSRequest::StartMeasure(measure) => start_measure(srv, measure).await,
            WSRequest::NewMeasureSeries(series) => add_measure_series(srv, series).await,
            WSRequest::ListMeasureSeries { bow_id } => list_measure_series(srv, bow_id).await,
            WSRequest::ListArrows { bow_id } => list_arrows(srv, bow_id).await,
            WSRequest::ListMeasures { series_id } => list_measures(srv, series_id).await,
            WSRequest::ListMeasurePoints { measure_id } => {
                list_measure_points(srv, measure_id).await
            }
            WSRequest::Command(command) => handle_arrow_command(srv, command).await,
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

async fn list_bows<F: ArrowDB>(srv: &Webserver<F>) -> std::result::Result<WSUpdate, WSError> {
    let bows = srv.db.list_bows().await?;
    Ok(WSUpdate::BowList(bows))
}

async fn add_bow<F: ArrowDB>(
    srv: &Webserver<F>,
    bow: Bow,
) -> std::result::Result<WSUpdate, WSError> {
    let bow = srv.db.add_bow(bow).await?;
    Ok(WSUpdate::BowList(vec![bow]))
}

async fn add_measure_series<F: ArrowDB>(
    srv: &Webserver<F>,
    series: MeasureSeries,
) -> std::result::Result<WSUpdate, WSError> {
    if series.draw_distance.is_none() && series.draw_force.is_none() {
        return Err(WSError::Logic(
            "either draw_distance or draw_force must be set".into(),
        ));
    }
    let series = srv.db.add_measure_series(series).await?;
    Ok(WSUpdate::MeasureSeriesList(vec![series]))
}

async fn list_measure_series<F: ArrowDB>(
    srv: &Webserver<F>,
    bow_id: i32,
) -> std::result::Result<WSUpdate, WSError> {
    let series = srv.db.list_measurement_series(bow_id).await?;
    Ok(WSUpdate::MeasureSeriesList(series))
}

async fn list_arrows<F: ArrowDB>(
    srv: &Webserver<F>,
    bow_id: i32,
) -> std::result::Result<WSUpdate, WSError> {
    let arrows = srv.db.list_arrows(bow_id).await?;
    Ok(WSUpdate::ArrowList(arrows))
}

async fn add_arrow<F: ArrowDB>(
    srv: &Webserver<F>,
    arrow: Arrow,
) -> std::result::Result<WSUpdate, WSError> {
    let arrow = srv.db.add_arrow(arrow).await?;
    Ok(WSUpdate::ArrowList(vec![arrow]))
}

async fn list_measures<F: ArrowDB>(
    srv: &Webserver<F>,
    series_id: i32,
) -> std::result::Result<WSUpdate, WSError> {
    let measures = srv.db.list_measures(series_id).await?;
    Ok(WSUpdate::MeasureList(measures))
}

async fn start_measure<F: ArrowDB>(
    srv: &Webserver<F>,
    measure: Measure,
) -> std::result::Result<WSUpdate, WSError> {
    let measure = srv.db.add_measure(measure).await?;
    Ok(WSUpdate::MeasureList(vec![measure]))
}

async fn list_measure_points<F: ArrowDB>(
    srv: &Webserver<F>,
    measure_id: i32,
) -> std::result::Result<WSUpdate, WSError> {
    let measure_points = srv.db.list_measure_points(measure_id).await?;
    Ok(WSUpdate::MeasurePointList(measure_points))
}

async fn handle_arrow_command<F: ArrowDB>(
    srv: &Webserver<F>,
    command: MachineCommand,
) -> std::result::Result<WSUpdate, WSError> {
    Ok(WSUpdate::Alive {})
}

#[cfg(test)]
mod test {
    use super::super::database::traits::MockDB;
    use super::*;
    fn mock_srv(db: MockDB) -> Webserver<impl ArrowDB> {
        let (tx, _rx) = tokio::sync::mpsc::channel(8);
        Webserver {
            shutdown_tx: tx,
            sockets: Arc::new(RwLock::new(HashMap::new())),
            db,
        }
    }
    #[tokio::test]
    async fn test_list_bows() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        let mut db = MockDB::new();
        let bow = Bow {
            id: 1,
            name: "bow".into(),
            max_draw_distance: 0.9,
            remainder_arrow_length: 0.1,
        };
        let bow_c = bow.clone();
        db.expect_list_bows().return_once(move || Ok(vec![bow_c]));
        let srv = mock_srv(db);

        handle_ws_message(
            &"".into(),
            WSMessage::Request(WSRequest::ListBows {}).into(),
            &srv,
            tx,
        )
        .await;
        let response = rx.recv().await.unwrap();
        assert_eq!(
            response.unwrap(),
            WSMessage::Response(WSUpdate::BowList(vec![bow])).into()
        );
    }
}
