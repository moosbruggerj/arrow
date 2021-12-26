use crate::message::WSUpdate;
use crate::models::*;
use async_trait::async_trait;
use tokio::sync::mpsc::UnboundedSender;

#[async_trait]
pub trait ArrowDB: Clone + Send + Sync {
    async fn list_bows(&self) -> Result<Vec<Bow>, sqlx::Error>;
    async fn add_bow(&self, bow: Bow) -> Result<Bow, sqlx::Error>;
    async fn update_bow(&self, bow: Bow) -> Result<Bow, sqlx::Error>;
    async fn delete_bow(&self, bow_id: i32) -> Result<i32, sqlx::Error>;

    async fn list_measurement_series(&self, id: i32) -> Result<Vec<MeasureSeries>, sqlx::Error>;
    async fn add_measure_series(&self, series: MeasureSeries)
        -> Result<MeasureSeries, sqlx::Error>;

    async fn list_arrows(&self, id: i32) -> Result<Vec<Arrow>, sqlx::Error>;
    async fn add_arrow(&self, arrow: Arrow) -> Result<Arrow, sqlx::Error>;

    async fn list_measures(&self, id: i32) -> Result<Vec<Measure>, sqlx::Error>;
    async fn add_measure(&self, measure: Measure) -> Result<Measure, sqlx::Error>;

    async fn list_measure_points(&self, id: i32) -> Result<Vec<MeasurePoint>, sqlx::Error>;

    async fn listener(self, channel: UnboundedSender<WSUpdate>) -> Result<(), sqlx::Error>;
}

#[cfg(test)]
mockall::mock! {
    pub DB {}
    #[async_trait]
    impl ArrowDB for DB {
    async fn list_bows(&self) -> Result<Vec<Bow>, sqlx::Error>;
    async fn add_bow(&self, bow: Bow) -> Result<Bow, sqlx::Error>;
    async fn update_bow(&self, bow: Bow) -> Result<Bow, sqlx::Error>;
    async fn delete_bow(&self, bow_id: i32) -> Result<(), sqlx::Error>;

    async fn list_measurement_series(&self, id: i32) -> Result<Vec<MeasureSeries>, sqlx::Error>;
    async fn add_measure_series(&self, series: MeasureSeries) -> Result<MeasureSeries, sqlx::Error>;

    async fn list_arrows(&self, id: i32) -> Result<Vec<Arrow>, sqlx::Error>;
    async fn add_arrow(&self, arrow: Arrow) -> Result<Arrow, sqlx::Error>;

    async fn list_measures(&self, id: i32) -> Result<Vec<Measure>, sqlx::Error>;
    async fn add_measure(&self, measure: Measure) -> Result<Measure, sqlx::Error>;

    async fn list_measure_points(&self, id: i32) -> Result<Vec<MeasurePoint>, sqlx::Error>;
    async fn listener(self, channel: UnboundedSender<WSUpdate>) -> Result<(), sqlx::Error>;
    }
    impl Clone for DB {
        fn clone(&self) -> Self;
    }
}
