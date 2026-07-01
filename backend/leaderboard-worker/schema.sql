CREATE TABLE IF NOT EXISTS leaderboard_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    player_name TEXT NOT NULL,
    duration INTEGER NOT NULL,
    score INTEGER NOT NULL,
    achieved_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(player_name, duration)
);

CREATE INDEX IF NOT EXISTS idx_leaderboard_duration_score
ON leaderboard_entries(duration, score DESC, achieved_at ASC);

CREATE TABLE IF NOT EXISTS request_rate_limits (
    rate_key TEXT PRIMARY KEY,
    ip_hash TEXT NOT NULL,
    action TEXT NOT NULL,
    bucket_start INTEGER NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_bucket
ON request_rate_limits(action, bucket_start);
