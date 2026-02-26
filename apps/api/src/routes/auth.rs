// apps/api/src/routes/auth.rs
use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::{IntoResponse, Redirect},
};
use chrono::{Duration, Utc};
use jsonwebtoken::{encode, EncodingKey, Header};
use reqwest::Client;
use serde::Deserialize;
use sqlx::PgPool;
use std::env;
use uuid::Uuid;
use crate::middleware::auth::Claims; // We'll define this in middleware/auth.rs

use super::super::db::users; // Assume we'll have db/users.rs with upsert_user_from_twitch etc.

#[derive(Deserialize)]
pub struct TwitchCallbackParams {
    code: String,
    state: Option<String>, // Optional state for intent, e.g., "create_streamer"
}

#[derive(Deserialize, Debug)]
struct TwitchTokenResponse {
    access_token: String,
    // Add other fields if needed, e.g., refresh_token
}

#[derive(Deserialize, Debug)]
struct TwitchUserResponse {
    data: Vec<TwitchUserData>,
}

#[derive(Deserialize, Debug)]
struct TwitchUserData {
    id: String,
    login: String,
    display_name: String,
    profile_image_url: Option<String>,
    email: Option<String>,
}

pub async fn twitch_login_init() -> Redirect {
    let client_id = env::var("TWITCH_CLIENT_ID").expect("TWITCH_CLIENT_ID missing");
    let redirect_uri = env::var("TWITCH_REDIRECT_URI").expect("TWITCH_REDIRECT_URI missing");
    
    // For simplicity, no state param here; can add if needed for CSRF
    let url = format!(
        "https://id.twitch.tv/oauth2/authorize?client_id={}&redirect_uri={}&response_type=code&scope=user:read:email",
        client_id, redirect_uri
    );

    Redirect::to(&url)
}

pub async fn twitch_callback(
    State(pool): State<PgPool>,
    Query(params): Query<TwitchCallbackParams>,
) -> Result<impl IntoResponse, StatusCode> {
    let client_id = env::var("TWITCH_CLIENT_ID").expect("TWITCH_CLIENT_ID missing");
    let client_secret = env::var("TWITCH_CLIENT_SECRET").expect("TWITCH_CLIENT_SECRET missing");
    let redirect_uri = env::var("TWITCH_REDIRECT_URI").expect("TWITCH_REDIRECT_URI missing");

    let http_client = Client::new();

    // Exchange code for token
    let token_res = http_client
        .post("https://id.twitch.tv/oauth2/token")
        .form(&[
            ("client_id", &client_id),
            ("client_secret", &client_secret),
            ("code", &params.code),
            ("grant_type", "authorization_code"),
            ("redirect_uri", &redirect_uri),
        ])
        .send()
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let token_data: TwitchTokenResponse = token_res
        .json()
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Get user info
    let user_res = http_client
        .get("https://api.twitch.tv/helix/users")
        .bearer_auth(&token_data.access_token)
        .header("Client-Id", client_id)
        .send()
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let user_data: TwitchUserResponse = user_res
        .json()
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let twitch_user = user_data.data.first().ok_or(StatusCode::NOT_FOUND)?;

    // Upsert user (using db/users.rs function)
    let user = users::upsert_user_from_twitch(
        &pool,
        &twitch_user.id,
        &twitch_user.login,
        &twitch_user.display_name,
        twitch_user.profile_image_url.as_deref(),
        twitch_user.email.as_deref(),
    ).await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Generate JWT
    let jwt_secret = env::var("JWT_SECRET").expect("JWT_SECRET missing");
    let expiration = Utc::now()
        .checked_add_signed(Duration::hours(24))
        .expect("valid timestamp")
        .timestamp() as usize;

    let claims = Claims {
        sub: user.id.to_string(),
        exp: expiration,
    };

    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(jwt_secret.as_bytes()),
    )
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Redirect to frontend with token (adjust base URL)
    let frontend_base = env::var("FRONTEND_BASE_URL").unwrap_or_else(|_| "http://localhost:5173".to_string());
    let redirect_url = format!("{}/callback?token={}", frontend_base, token);

    Ok(Redirect::to(&redirect_url))
}