pub mod implementation;
pub mod traits;

pub use self::traits::ArrowDB;
//pub type ArrowDB = self::traits::ArrowDB + Clone;
pub use implementation::PgArrowDB;
