mod message;
use std::error::Error;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}

pub struct Hardware {}

impl Hardware {
    pub fn new() -> Result<Self, Box<dyn Error>> {
        Ok(Hardware {})
    }

    pub fn start(&mut self) {}
}
