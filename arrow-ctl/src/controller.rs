use crate::message;
use crate::server::Webserver;
use std::error::Error;
use tokio::sync::{broadcast, mpsc};
use tokio::time::interval;

const CONTROL_CHANNEL_SIZE: usize = 32;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}

pub struct Controller {
    pub ctl_rx: broadcast::Receiver<message::ControlMessage>,
    pub ctl_tx: mpsc::Sender<message::ControlMessage>,
    pub server: Webserver,
    ctl_send_tx: broadcast::Sender<message::ControlMessage>,
    ctl_recv_rx: mpsc::Receiver<message::ControlMessage>,
}

impl Controller {
    pub fn new(server: Webserver) -> Result<Self, Box<dyn Error>> {
        let (recv_tx, recv_rx) = tokio::sync::mpsc::channel(CONTROL_CHANNEL_SIZE);
        let (send_tx, send_rx) = tokio::sync::broadcast::channel(CONTROL_CHANNEL_SIZE);
        Ok(Self {
            ctl_tx: recv_tx,
            ctl_recv_rx: recv_rx,
            server,
            ctl_send_tx: send_tx,
            ctl_rx: send_rx,
        })
    }

    pub async fn start(&mut self) {
        let _ = self.ctl_send_tx;
        /*
        let srv = self.server.clone();
        tokio::spawn(async move {
            let mut int = interval(std::time::Duration::from_secs(3));
            int.tick().await;
            loop {
                int.tick().await;
                srv.broadcast(message::WSUpdate::Alive)
                    .await;
            }
        });
        */
        while let Some(msg) = self.ctl_recv_rx.recv().await {
            use message::ControlMessage::*;
            match msg {
                Terminate => {
                    break;
                }
            }
        }
    }
}
