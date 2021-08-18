use super::ArrowDB;
use crate::message::WSUpdate;
use crate::message::WSUpdate::*;
use crate::models::*;

use async_trait::async_trait;

use sqlx::postgres::PgListener;
use sqlx::PgPool;

use tokio::sync::mpsc::UnboundedSender;
use tokio_stream::StreamExt;

use log::trace;

macro_rules! table_matcher {
    ($result:ident, $data:ident, $pool:ident, $(($table:literal, $model:ident, $update:ident)),+) => {
        match $result {
            $($table => query_table!($table, $model, $update, $pool, $data)),+
            ,
            _ => None
        }
    }
}

macro_rules! query_table {
    ($table:literal, $model:ident, $update:ident, $pool:ident, $data:ident) => {
        if let Ok(update) = sqlx::query_as!(
            $model,
            "SELECT * FROM " + $table + " WHERE id = ANY($1::INT[])",
            &$data
        )
        .fetch_all($pool)
        .await
        {
            Some($update(update))
        } else {
            None
        }
    };
}

#[derive(Clone)]
pub struct PgArrowDB {
    pool: PgPool,
}

impl PgArrowDB {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl ArrowDB for PgArrowDB {
    async fn list_bows(&self) -> Result<Vec<Bow>, sqlx::Error> {
        let bows = sqlx::query_as!(Bow, "SELECT * FROM bow")
            .fetch_all(&self.pool)
            .await?;
        Ok(bows)
    }

    async fn add_bow(&self, bow: Bow) -> Result<Bow, sqlx::Error> {
        let rec = sqlx::query!(
            r#"INSERT INTO bow 
            (name, max_draw_distance, remainder_arrow_length)
            VALUES ($1, $2, $3)
            RETURNING id"#,
            bow.name,
            bow.max_draw_distance,
            bow.remainder_arrow_length
        )
        .fetch_one(&self.pool)
        .await?;
        Ok(Bow { id: rec.id, ..bow })
    }

    async fn list_measurement_series(&self, id: i32) -> Result<Vec<MeasureSeries>, sqlx::Error> {
        let series = sqlx::query_as!(
            MeasureSeries,
            "SELECT * FROM measure_series WHERE bow_id = $1",
            id
        )
        .fetch_all(&self.pool)
        .await?;
        Ok(series)
    }

    async fn add_measure_series(
        &self,
        series: MeasureSeries,
    ) -> Result<MeasureSeries, sqlx::Error> {
        let rec = sqlx::query!(
            r#"INSERT INTO measure_series 
            (name, rest_position, draw_distance, draw_force, time, bow_id)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING id"#,
            series.name,
            series.rest_position,
            series.draw_distance,
            series.draw_force,
            series.time,
            series.bow_id,
        )
        .fetch_one(&self.pool)
        .await?;
        Ok(MeasureSeries {
            id: rec.id,
            ..series
        })
    }

    async fn list_arrows(&self, id: i32) -> Result<Vec<Arrow>, sqlx::Error> {
        let arrows = sqlx::query_as!(Arrow, "SELECT * FROM arrow WHERE bow_id = $1", id)
            .fetch_all(&self.pool)
            .await?;
        Ok(arrows)
    }

    async fn add_arrow(&self, arrow: Arrow) -> Result<Arrow, sqlx::Error> {
        let rec = sqlx::query!(
            r#"INSERT INTO arrow 
            (name, head_weight, spline, feather_length, feather_type, length, weight, bow_id)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING id"#,
            arrow.name,
            arrow.head_weight,
            arrow.spline,
            arrow.feather_length,
            arrow.feather_type,
            arrow.length,
            arrow.weight,
            arrow.bow_id,
        )
        .fetch_one(&self.pool)
        .await?;
        Ok(Arrow {
            id: rec.id,
            ..arrow
        })
    }

    async fn list_measures(&self, id: i32) -> Result<Vec<Measure>, sqlx::Error> {
        let measures = sqlx::query_as!(
            Measure,
            "SELECT * FROM measure WHERE measure_series_id = $1",
            id
        )
        .fetch_all(&self.pool)
        .await?;
        Ok(measures)
    }

    async fn add_measure(&self, measure: Measure) -> Result<Measure, sqlx::Error> {
        let rec = sqlx::query!(
            r#"INSERT INTO measure 
            (measure_interval, measure_series_id, arrow_id)
            VALUES ($1, $2, $3)
            RETURNING id"#,
            measure.measure_interval,
            measure.measure_series_id,
            measure.arrow_id,
        )
        .fetch_one(&self.pool)
        .await?;
        Ok(Measure {
            id: rec.id,
            ..measure
        })
    }

    async fn list_measure_points(&self, id: i32) -> Result<Vec<MeasurePoint>, sqlx::Error> {
        let measure_points = sqlx::query_as!(
            MeasurePoint,
            "SELECT * FROM measure_point WHERE measure_id = $1",
            id
        )
        .fetch_all(&self.pool)
        .await?;
        Ok(measure_points)
    }

    async fn listener(self, channel: UnboundedSender<WSUpdate>) -> Result<(), sqlx::Error> {
        let mut listener = PgListener::connect_with(&self.pool).await?;
        listener.listen_all(vec!["update"]).await?;
        let mut stream = listener.into_stream();
        while let Some(notification) = stream.try_next().await? {
            trace!("notification: {:#?}", notification);
            let mut split = notification.payload().splitn(2, ",");
            if let (Some(table), Some(ids)) = (split.next(), split.next()) {
                let ids: Vec<i32> = ids
                    .split(",")
                    .filter_map(|id| id.parse::<i32>().ok())
                    .collect();
                let pool = &self.pool;
                let response = table_matcher!(
                    table,
                    ids,
                    pool,
                    ("bow", Bow, BowList),
                    ("arrow", Arrow, ArrowList),
                    ("measure_series", MeasureSeries, MeasureSeriesList),
                    ("measure_point", MeasurePoint, MeasurePointList),
                    ("measure", Measure, MeasureList)
                );
                if let Some(update) = response {
                    let send = channel.send(update);
                    if send.is_err() {
                        break;
                    }
                }
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod test {
    pub async fn connect_and_configure(conn_url: &str) -> Result<PgArrowDB, sqlx::Error> {
        let pool = PgPool::connect(conn_url).await?;
        sqlx::migrate!("db/migrations").run(&pool).await?;
        Ok(PgArrowDB::new(pool))
    }
}
