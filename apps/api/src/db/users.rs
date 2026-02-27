// apps/api/src/db/users.rs (New file for user queries)
use sqlx::{PgPool, Row};
use uuid::Uuid;
use chrono::Utc;

#[derive(Debug, sqlx::FromRow)]
pub struct User {
    pub id: Uuid,
    pub twitch_id: String,
    pub twitch_username: String,
    pub twitch_display_name: String,
    pub twitch_avatar_url: Option<String>,
    pub twitch_email: Option<String>,
    pub wallet_address: Option<String>,
    pub wallet_created_at: Option<chrono::DateTime<Utc>>,
    pub refresh_token_hash: Option<String>,
    pub last_seen_at: Option<chrono::DateTime<Utc>>,
    pub global_mana_balance: i64,
    pub global_credits_balance_cents: i32,
    pub is_admin: bool,
    pub is_banned: bool,
    pub welcome_drop_claimed: bool,
    pub anonymous_market: bool,
    pub created_at: chrono::DateTime<Utc>,
    pub updated_at: chrono::DateTime<Utc>,
}

pub async fn upsert_user_from_twitch(
    pool: &PgPool,
    twitch_id: &str,
    username: &str,
    display_name: &str,
    avatar_url: Option<&str>,
    email: Option<&str>,
) -> Result<User, sqlx::Error> {
    let mut tx = pool.begin().await?;

    let user = sqlx::query_as!(
        User,
        r#"
        INSERT INTO users (
            twitch_id, twitch_username, twitch_display_name, twitch_avatar_url, twitch_email
        )
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (twitch_id) DO UPDATE SET
            twitch_username = EXCLUDED.twitch_username,
            twitch_display_name = EXCLUDED.twitch_display_name,
            twitch_avatar_url = EXCLUDED.twitch_avatar_url,
            twitch_email = EXCLUDED.twitch_email,
            last_seen_at = NOW()
        RETURNING *
        "#,
        twitch_id, username, display_name, avatar_url, email
    )
    .fetch_one(&mut *tx)
    .await?;

    // Optional: Create membership for demo streamer if state indicates
    // For now, skip; handle in handler if needed

    tx.commit().await?;

    Ok(user)
}