// apps/api/src/seed.rs (New file for seeding)
use sqlx::PgPool;
use uuid::Uuid;

pub async fn run_seed(pool: &PgPool) -> Result<(), sqlx::Error> {
    // Seed demo streamer (your Twitch)
    let demo_twitch_id = "your_twitch_id_here"; // Replace with your actual
    let demo_username = "your_username";
    let demo_display = "Your Display Name";

    sqlx::query!(
        r#"
        INSERT INTO users (twitch_id, twitch_username, twitch_display_name)
        VALUES ($1, $2, $3)
        ON CONFLICT DO NOTHING
        "#,
        demo_twitch_id, demo_username, demo_display
    )
    .execute(pool)
    .await?;

    let user_id = sqlx::query_scalar!(
        "SELECT id FROM users WHERE twitch_id = $1",
        demo_twitch_id
    )
    .fetch_one(pool)
    .await?;

    sqlx::query!(
        r#"
        INSERT INTO streamers (user_id, twitch_channel_id, twitch_channel_name, brand_color)
        VALUES ($1, $2, $3, '#D97B3A')
        ON CONFLICT DO NOTHING
        "#,
        user_id, demo_twitch_id, demo_username
    )
    .execute(pool)
    .await?;

    // Add more: Sample assets, memberships, etc.
    // E.g., insert into assets...

    Ok(())
}