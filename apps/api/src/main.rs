// apps/api/src/main.rs
use axum::{routing::get, Router};
use std::net::SocketAddr;
use tokio::net::TcpListener;

mod config;

#[tokio::main]
async fn main() {
    dotenv::dotenv().ok();
    env_logger::init();

    let config = config::Config::from_env().expect("Failed to load config");
    let pool = config.create_pool().await;

    let app = Router::new()
        .route("/health", get(health_handler));

    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    let listener = TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn health_handler() -> &'static str {
    "OK"
}