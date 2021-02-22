use serde::{Serialize, Deserialize};

#[derive(Clone)]
pub enum ControlMessage {
    Terminate,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct WSRegisterResponse {
    pub url: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub enum WSUpdate {
    Alive,
    Simple(String),
}

#[derive(Serialize, Deserialize, Debug)]
pub enum WSMessage {
}
