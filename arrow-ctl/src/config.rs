use log::LevelFilter;
use serde::{Deserialize, Serialize};

pub struct CmdArgs {
    pub verbosity: LevelFilter,
    pub config_file: Option<String>,
    pub log_file: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(default)]
pub struct DBConfiguration {
    pub user: String,
    pub host: String,
    pub port: u32,
    pub db: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(default)]
pub struct Configuration {
    pub db: DBConfiguration,
    pub draw_measure_interval: f64,
    pub hold_time: f64,
    pub speed_measure_distance: f64,
    pub distance_per_rotation: f64,
    pub max_draw_distance: f64,
    pub max_draw_force: f64,
}

impl Default for DBConfiguration {
    fn default() -> Self {
        Self {
            user: "arrow".to_string(),
            host: "localhost".to_string(),
            port: 5432,
            db: "arrow".to_string(),
        }
    }
}

impl Default for Configuration {
    fn default() -> Self {
        Self {
            db: Default::default(),
            draw_measure_interval: 10e-3,
            hold_time: 100e-3,
            speed_measure_distance: 20e-2,
            distance_per_rotation: 30e-3,
            max_draw_distance: 0.85,
            max_draw_force: 30.0,
        }
    }
}

impl Default for CmdArgs {
    fn default() -> Self {
        Self {
            verbosity: LevelFilter::Warn,
            config_file: None,
            log_file: "/tmp/arrow.log".to_string(),
        }
    }
}
