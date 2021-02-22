use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::mpsc;
use tokio::sync::RwLock;

#[derive(Clone, Debug)]
pub struct WSocket {
    pub sender: Option<mpsc::UnboundedSender<std::result::Result<warp::ws::Message, warp::Error>>>,
}

pub type Clients = Arc<RwLock<HashMap<String, WSocket>>>;
