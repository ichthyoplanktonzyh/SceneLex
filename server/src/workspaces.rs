//! Workspace bootstrap and management.
//! Mirrors the reference behaviour: first authenticated request auto-provisions
//! user settings and a "Personal" workspace.

use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::AuthUser;

const AUTO_CREATED_WORKSPACE_NAME: &str = "Personal";

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct WorkspaceRow {
    pub workspace_id: Uuid,
    pub name: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub fsrs_desired_retention: f64,
    pub fsrs_learning_steps_minutes: serde_json::Value,
    pub fsrs_relearning_steps_minutes: serde_json::Value,
    pub fsrs_maximum_interval_days: i32,
    pub fsrs_enable_fuzz: bool,
}

/// Ensure user_settings row exists and at least one workspace exists;
/// returns the selected workspace id.
pub async fn ensure_user_bootstrap(pool: &PgPool, user: &AuthUser) -> Result<Uuid, sqlx::Error> {
    let user_id = user.user_id;

    sqlx::query(
        "INSERT INTO org.user_settings (user_id, progress_time_zone)
         VALUES ($1, 'UTC')
         ON CONFLICT (user_id) DO NOTHING",
    )
    .bind(user_id)
    .execute(pool)
    .await?;

    let selected: Option<Uuid> = sqlx::query_scalar(
        "SELECT selected_workspace_id FROM org.user_settings WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_one(pool)
    .await?;

    if let Some(workspace_id) = selected {
        // Verify the selected workspace is still accessible.
        let exists: Option<Uuid> = sqlx::query_scalar(
            "SELECT workspace_id FROM org.workspace_memberships
             WHERE user_id = $1 AND workspace_id = $2",
        )
        .bind(user_id)
        .bind(workspace_id)
        .fetch_optional(pool)
        .await?;
        if exists.is_some() {
            return Ok(workspace_id);
        }
    }

    // No valid selection: pick the earliest workspace, or create "Personal".
    let earliest: Option<Uuid> = sqlx::query_scalar(
        "SELECT w.workspace_id
         FROM org.workspace_memberships m
         JOIN org.workspaces w ON w.workspace_id = m.workspace_id
         WHERE m.user_id = $1
         ORDER BY w.created_at ASC
         LIMIT 1",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?;

    let workspace_id = match earliest {
        Some(id) => id,
        None => {
            let id = Uuid::new_v4();
            sqlx::query("INSERT INTO org.workspaces (workspace_id, name) VALUES ($1, $2)")
                .bind(id)
                .bind(AUTO_CREATED_WORKSPACE_NAME)
                .execute(pool)
                .await?;
            sqlx::query(
                "INSERT INTO org.workspace_memberships (workspace_id, user_id, role)
                 VALUES ($1, $2, 'owner')",
            )
            .bind(id)
            .bind(user_id)
            .execute(pool)
            .await?;
            id
        }
    };

    sqlx::query(
        "UPDATE org.user_settings SET selected_workspace_id = $1 WHERE user_id = $2",
    )
    .bind(workspace_id)
    .bind(user_id)
    .execute(pool)
    .await?;

    Ok(workspace_id)
}

pub async fn list_workspaces(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<Vec<WorkspaceRow>, sqlx::Error> {
    sqlx::query_as::<_, WorkspaceRow>(
        "SELECT w.workspace_id, w.name, w.created_at,
                w.fsrs_desired_retention, w.fsrs_learning_steps_minutes,
                w.fsrs_relearning_steps_minutes, w.fsrs_maximum_interval_days,
                w.fsrs_enable_fuzz
         FROM org.workspaces w
         JOIN org.workspace_memberships m ON m.workspace_id = w.workspace_id
         WHERE m.user_id = $1
         ORDER BY w.created_at ASC",
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
}

pub async fn create_workspace(
    pool: &PgPool,
    user_id: Uuid,
    name: &str,
) -> Result<WorkspaceRow, sqlx::Error> {
    let id = Uuid::new_v4();
    sqlx::query("INSERT INTO org.workspaces (workspace_id, name) VALUES ($1, $2)")
        .bind(id)
        .bind(name)
        .execute(pool)
        .await?;
    sqlx::query(
        "INSERT INTO org.workspace_memberships (workspace_id, user_id, role)
         VALUES ($1, $2, 'owner')",
    )
    .bind(id)
    .bind(user_id)
    .execute(pool)
    .await?;
    sqlx::query(
        "UPDATE org.user_settings SET selected_workspace_id = $1 WHERE user_id = $2",
    )
    .bind(id)
    .bind(user_id)
    .execute(pool)
    .await?;
    list_workspace(pool, id).await
}

pub async fn select_workspace(
    pool: &PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
) -> Result<bool, sqlx::Error> {
    let member: Option<Uuid> = sqlx::query_scalar(
        "SELECT workspace_id FROM org.workspace_memberships
         WHERE user_id = $1 AND workspace_id = $2",
    )
    .bind(user_id)
    .bind(workspace_id)
    .fetch_optional(pool)
    .await?;

    if member.is_none() {
        return Ok(false);
    }

    sqlx::query("UPDATE org.user_settings SET selected_workspace_id = $1 WHERE user_id = $2")
        .bind(workspace_id)
        .bind(user_id)
        .execute(pool)
        .await?;
    Ok(true)
}

async fn list_workspace(pool: &PgPool, workspace_id: Uuid) -> Result<WorkspaceRow, sqlx::Error> {
    sqlx::query_as::<_, WorkspaceRow>(
        "SELECT workspace_id, name, created_at,
                fsrs_desired_retention, fsrs_learning_steps_minutes,
                fsrs_relearning_steps_minutes, fsrs_maximum_interval_days,
                fsrs_enable_fuzz
         FROM org.workspaces WHERE workspace_id = $1",
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await
}
