use time::OffsetDateTime;
use serde::{self, Deserialize, Deserializer, Serializer};

//TODO: remove with upgrade to time v0.3, as it provides serde-human-readable, which does this in
//a more configurable way
const ISO_FORMAT: &'static str = "%FT%TZ%z"; // "2020-01-30T12:30:00Z+0100"

pub fn serialize<S>(date: &OffsetDateTime, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    let s = date.format(ISO_FORMAT);
    serializer.serialize_str(&s)
}

pub fn deserialize<'de, D>(deserializer: D) -> Result<OffsetDateTime, D::Error>
where
    D: Deserializer<'de>,
{
    let s = String::deserialize(deserializer)?;
    OffsetDateTime::parse(&s, ISO_FORMAT).map_err(serde::de::Error::custom)
}
