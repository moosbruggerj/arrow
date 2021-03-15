use super::models::*;
use log::error;
use serde::{Deserialize, Serialize};
use std::convert::TryFrom;
use std::result::Result;

#[derive(Clone)]
pub enum ControlMessage {
    Terminate,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct WSRegisterResponse {
    pub url: String,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "lowercase")]
pub enum WSUpdate {
    Alive {},
    BowList(Vec<Bow>),
    MeasureSeriesList(Vec<MeasureSeries>),
    ArrowList(Vec<Arrow>),
    MeasureList(Vec<Measure>),
    MeasurePointList(Vec<MeasurePoint>),
    Status(MachineStatus),
    Error(String),
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "lowercase")]
pub enum WSRequest {
    ListBows {},
    ListMeasureSeries { bow_id: i32 },
    ListArrows { bow_id: i32 },
    ListMeasures { series_id: i32 },
    ListMeasurePoints { measure_id: i32 },
    AddBow(Bow),
    AddArrow(Arrow),
    NewMeasureSeries(MeasureSeries),
    StartMeasure(Measure),
    Command(MachineCommand),
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "lowercase")]
pub enum MachineCommand {
    Calibrate,
    Reset,
    Restart,
    Shutdown,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "lowercase")]
pub enum WSMessage {
    Request(WSRequest),
    Update(WSUpdate),
    Response(WSUpdate),
}

impl Into<warp::ws::Message> for WSMessage {
    fn into(self) -> warp::ws::Message {
        warp::ws::Message::text(serde_json::ser::to_string(&self).unwrap_or_else(|e| {
            let err = format!("error serializing upate: {}", e);
            error!("{}", err);
            serde_json::ser::to_string(&WSUpdate::Error(err)).unwrap()
        }))
    }
}

impl TryFrom<warp::ws::Message> for WSMessage {
    type Error = serde_json::Error;

    fn try_from(msg: warp::ws::Message) -> Result<WSMessage, serde_json::Error> {
        let str = msg.to_str().unwrap_or("");
        serde_json::de::from_str(&str)
    }
}
