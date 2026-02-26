// apps/api/src/main.rs
use axum::{routing::get, Router};
use std::net::SocketAddr;
use tokio::net::TcpListener;

mod config;

#[tokio::main]
async fn main() {
    dotenv::dotenv().ok();
    env_logger::init();

    let config = Config::from_env().expect("Failed to load config");
    let pool = config.create_pool().await;

    // Run migrations
    sqlx::migrate!("./migrations").run(&pool).await.expect("Migration failed");

    // Seed if empty
    let data_exists: bool = sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM users LIMIT 1)")
        .fetch_one(&pool)
        .await
        .unwrap_or(false);

    if !data_exists {
        seed::run_seed(&pool).await.expect("Seeding failed");
    }

    let app = Router::new()
        .route("/health", get(super::health_handler))
        .route("/auth/twitch", get(twitch_login_init))
        .route("/auth/callback", get(twitch_callback).with_state(pool.clone()));

    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    let listener = TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn health_handler() -> &'static str {
    "OK"
}