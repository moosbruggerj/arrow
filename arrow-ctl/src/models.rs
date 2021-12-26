use crate::serde_timestamp;
use serde::{Deserialize, Serialize};
use time::OffsetDateTime;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Bow {
    #[serde(default = "invalid_id")]
    pub id: i32,
    pub name: String,
    pub max_draw_distance: f32,
    pub remainder_arrow_length: f32,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct MeasureSeries {
    #[serde(default = "invalid_id")]
    pub id: i32,
    pub name: String,
    pub rest_position: f32,
    #[serde(default)]
    pub draw_distance: Option<f32>,
    #[serde(default)]
    pub draw_force: Option<f32>,
    #[serde(with = "serde_timestamp")]
    pub time: OffsetDateTime,
    pub bow_id: i32,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Arrow {
    #[serde(default = "invalid_id")]
    pub id: i32,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub head_weight: Option<f32>,
    #[serde(default)]
    pub spline: Option<f32>,
    #[serde(default)]
    pub feather_length: Option<f32>,
    #[serde(default)]
    pub feather_type: Option<String>,
    pub length: f32,
    pub weight: f32,
    pub bow_id: i32,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Measure {
    #[serde(default = "invalid_id")]
    pub id: i32,
    pub measure_interval: f32,
    pub measure_series_id: i32,
    pub arrow_id: i32,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct MeasurePoint {
    #[serde(default = "invalid_id")]
    pub id: i32,
    pub time: i64,
    pub draw_distance: f64,
    pub force: f64,
    pub measure_id: i32,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "lowercase")]
pub enum MachineStatus {
    Pause,
    Shooting,
    Error,
}

pub fn invalid_id() -> i32 {
    -1
}
