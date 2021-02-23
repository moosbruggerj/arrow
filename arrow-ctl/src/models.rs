use time::OffsetDateTime;
use serde::{Serialize,Deserialize};
use crate::serde_timestamp;

#[derive(Serialize, Deserialize, Debug)]
pub struct Bow {
    #[serde(default="invalid_id")]
    pub id: i32,
    pub name: String,
    pub max_draw_distance: f32,
    pub remainder_arrow_length: f32,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct MeasureSeries {
    #[serde(default="invalid_id")]
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

fn invalid_id() -> i32 {
    -1
}
