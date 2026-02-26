// apps/api/src/config.rs
use sqlx::PgPool;
use std::env;

pub struct Config {
    pub database_url: String,
    pub redis_url: String,
    // Add more as needed (TWITCH_CLIENT_ID, etc.)
}

impl Config {
    pub fn from_env() -> Result<Self, env::VarError> {
        Ok(Self {
            database_url: env::var("DATABASE_URL")?,
            redis_url: env::var("REDIS_URL")?,
        })
    }

    pub async fn create_pool(&self) -> PgPool {
        sqlx::PgPool::connect(&self.database_url).await.expect("Failed to connect to DB")
    }

    // Add redis_client() later
}