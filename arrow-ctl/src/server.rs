pub mod handler;
//pub mod notification;
pub mod database;

use super::config::Configuration;
use super::message::WSUpdate;
use log::{error, trace};
use sqlx::PgPool;
use std::collections::HashMap;
use std::error::Error;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::mpsc;
use tokio::sync::RwLock;
use warp::Filter;

const SHUTDOWN_CHANNEL_SIZE: usize = 8;

#[derive(Clone, Debug)]
pub struct Webserver<F>
where
    F: database::ArrowDB + Clone + Send,
{
    pub shutdown_tx: mpsc::Sender<()>,
    sockets: handler::Clients,
    db: F,
}

impl<F: database::ArrowDB + Clone + Send + 'static> Webserver<F> {
    pub fn new(shutdown_tx: mpsc::Sender<()>, db: F) -> Self {
        Self {
            shutdown_tx,
            sockets: Arc::new(RwLock::new(HashMap::new())),
            db,
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

    pub fn listen(self) {
        let srv = self.clone();
        let (tx, mut rx) = mpsc::unbounded_channel();
        tokio::spawn(async move {
            while let Some(msg) = rx.recv().await {
                self.broadcast(msg).await;
            }
        });
        tokio::spawn(async move { srv.db.listener(tx).await });
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

fn register_routes<F: database::ArrowDB + 'static>(
    db: Webserver<F>,
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
        .or(warp::path("static").and(warp::fs::dir("./static")))
        .or(warp::get()
            .and(warp::fs::file("./static/arrow.html")))
        .or_else(|_| async { Err(warp::reject()) });
    routes
}

fn with_db<F: database::ArrowDB>(
    db: Webserver<F>,
) -> impl Filter<Extract = (Webserver<F>,), Error = std::convert::Infallible> + Clone {
    warp::any().map(move || db.clone())
}

pub async fn new(
    config: &Configuration,
) -> Result<
    (
        Builder<impl Filter<Extract = impl warp::Reply, Error = warp::Rejection> + Clone>,
        Webserver<impl database::ArrowDB>,
    ),
    Box<(dyn Error)>,
> {
    Builder::from_factory(config, Box::new(register_routes)).await
}

impl<F> Builder<F>
where
    F: Filter + Clone + Send + Sync + 'static,
    F::Extract: warp::Reply,
{
    //type RouteType = impl Filter<Extract = impl warp::Reply, Error = warp::Rejection> + Clone
    pub async fn from_factory(
        config: &Configuration,
        routes_factory: Box<dyn Fn(Webserver<database::PgArrowDB>) -> F>,
    ) -> Result<(Self, Webserver<database::PgArrowDB>), Box<dyn Error>> {
        let (tx, rx): (mpsc::Sender<()>, _) = mpsc::channel(SHUTDOWN_CHANNEL_SIZE);
        let db_conn_str = format!(
            "postgres://{}:{}@{}:{}/{}",
            config.db.user, config.db.password, config.db.host, config.db.port, config.db.db
        );
        let pool = PgPool::connect(&db_conn_str).await?;
        let db = database::PgArrowDB::new(pool);

        let wsrv = Webserver::new(tx, db);
        let notification_srv = wsrv.clone();

        notification_srv.listen();

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
