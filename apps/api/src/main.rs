// apps/api/src/main.rs
use axum::{routing::get, Router};
use sqlx::PgPool;
use std::net::SocketAddr;
use tokio::net::TcpListener;

mod config;
use config::Config;

//temporary insertions to get this running

mod db; // Now top-level: This loads src/db/mod.rs, which has pub mod users;
mod middleware {
    pub mod auth;
}

mod routes {
    pub mod auth;
}

mod seed;

use routes::auth::{twitch_login_init, twitch_callback};
use seed::run_seed;



#[tokio::main]
async fn main() {
dotenv::dotenv().ok();
    env_logger::init();

    let config = Config::from_env().expect("Failed to load config");
    let pool = config.create_pool().await;

    sqlx::migrate!("./migrations").run(&pool).await.expect("Migration failed");

    // seed if empty
    let data_exists: bool = sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM users LIMIT 1)")
        .fetch_one(&pool)
        .await
        .unwrap_or(false);

    if !data_exists {
        run_seed(&pool).await.expect("Seeding failed");
    }

    let app = Router::new()
        .route("/health", get(health_handler))
        .route("/auth/twitch", get(twitch_login_init))
        .route("/auth/callback", get(twitch_callback).with_state(pool.clone()));

    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    let listener = TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn health_handler() -> &'static str {
    "OK"
}