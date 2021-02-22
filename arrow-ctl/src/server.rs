pub mod handler;
mod models;

use super::message::WSUpdate;
use log::{trace, error};
use std::collections::HashMap;
use std::error::Error;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::mpsc;
use tokio::sync::RwLock;
use warp::Filter;

#[derive(Clone,Debug)]
pub struct Webserver {
    pub shutdown_tx: mpsc::Sender<()>,
    sockets: models::Clients,
}

impl Webserver {
    pub fn new(shutdown_tx: mpsc::Sender<()>) -> Self {
        Self {
            shutdown_tx,
            sockets: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub async fn broadcast(&self, msg: WSUpdate) {
        trace!("broadcasting: {:#?}", msg);
        self.sockets
            .read()
            .await
            .iter()
            .filter_map(|(_, client)| client.sender.as_ref())
            .for_each(|sender| {
                let _ = sender.send(Ok(warp::ws::Message::text(
                    serde_json::ser::to_string(&msg).unwrap_or_else(|e| {
                        error!("cannot parse WSUpdate: '{}'", e);
                        String::from("")
                    }),
                )));
            });
    }
}

pub struct Builder<F>
where
    F: Filter + Clone + Send + Sync + 'static,
    F::Extract: warp::Reply,
{
    server: warp::Server<F>,
    shutdown_rx: mpsc::Receiver<()>,
}

fn register_routes(
    db: Webserver,
) -> impl Filter<Extract = impl warp::Reply, Error = warp::Rejection> + Clone {
    //let base = warp::any().map(move || db.clone());
    //let api = base.and(warp::path("api"));
    let routes = warp::path!("api" / "client" / "new")
        .and(with_db(db.clone()))
        .and_then(handler::new_client)
        .or(with_db(db.clone())
            .and(warp::path!("api" / "client" / "delete" / String))
            .and(warp::delete())
            .and_then(handler::delete_client))
        .or(with_db(db.clone())
            .and(warp::ws())
            .and(warp::path!("ws" / String))
            .and_then(handler::ws_connect))
        .or_else(|_| async { Err(warp::reject())});
    routes
}

fn with_db(
    db: Webserver,
) -> impl Filter<Extract = (Webserver,), Error = std::convert::Infallible> + Clone {
    warp::any().map(move || db.clone())
}

pub fn new() -> Result<
    (
        Builder<impl Filter<Extract = impl warp::Reply, Error = warp::Rejection> + Clone>,
        Webserver,
    ),
    Box<(dyn Error)>,
> {
    Builder::from_factory(Box::new(register_routes))
}

impl<F> Builder<F>
where
    F: Filter + Clone + Send + Sync + 'static,
    F::Extract: warp::Reply,
{
    //type RouteType = impl Filter<Extract = impl warp::Reply, Error = warp::Rejection> + Clone
    pub fn from_factory(
        routes_factory: Box<dyn Fn(Webserver) -> F>,
    ) -> Result<(Self, Webserver), Box<dyn Error>> {
        let (tx, rx): (mpsc::Sender<()>, _) = mpsc::channel(8);
        let wsrv = Webserver::new(tx);
        let server = warp::serve(routes_factory(wsrv.clone()));
        let instance = Self {
            server,
            shutdown_rx: rx,
        };
        Ok((instance, wsrv))
    }

    pub fn bind(
        self,
        addr: impl Into<SocketAddr> + 'static,
    ) -> Result<(SocketAddr, impl std::future::Future<Output = ()>), impl Error> {
        let (server, mut rx) = (self.server, self.shutdown_rx);
        server
            .try_bind_with_graceful_shutdown(addr, async move {
                rx.recv().await;
                rx.close();
                //empty recv buffer
                while let Some(_) = rx.recv().await {}
            })
            .or_else(|e| {
                error!("cannot create webserver: '{}'", e);
                Err(e)
            })
    }
}
