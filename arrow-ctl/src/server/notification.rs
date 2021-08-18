use super::Webserver;
use super::database::ArrowDB;
use crate::message::WSUpdate::*;
use crate::models::*;
use log::trace;
use sqlx::postgres::PgListener;
use std::result::Result;
use tokio_stream::StreamExt;

macro_rules! table_matcher {
    ($result:ident, $data:ident, $srv:ident, $(($table:literal, $model:ident, $update:ident)),+) => {
        match $result {
            $($table => query_table!($table, $model, $update, $srv, $data)),+
            ,
            _ => None
        }
    }
}

macro_rules! query_table {
    ($table:literal, $model:ident, $update:ident, $srv:ident, $data:ident) => {
        if let Ok(update) = sqlx::query_as!(
            $model,
            "SELECT * FROM " + $table + " WHERE id = ANY($1::INT[])",
            &$data
        )
        .fetch_all(&$srv.db.db_pool)
        .await
        {
            Some($update(update))
        } else {
            None
        }
    };
}

pub async fn notification_listener<F: ArrowDB>(
    mut listener: PgListener,
    srv: Webserver<F>,
) -> Result<(), sqlx::Error> {
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
            let response = table_matcher!(
                table,
                ids,
                srv,
                ("bow", Bow, BowList),
                ("arrow", Arrow, ArrowList),
                ("measure_series", MeasureSeries, MeasureSeriesList),
                ("measure_point", MeasurePoint, MeasurePointList),
                ("measure", Measure, MeasureList)
            );
            if let Some(update) = response {
                srv.broadcast(update).await;
            }
        }
    }
    Ok(())
}
