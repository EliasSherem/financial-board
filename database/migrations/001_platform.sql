-- FinSight platform foundation. Explicit migration only; never run automatically at API boot.
-- MySQL 8 / InnoDB. All timestamps are UTC. User cascades remove personal ledgers on account deletion.

CREATE TABLE IF NOT EXISTS platform_rate_limits (
bucket_key CHAR(64) NOT NULL, window_start DATETIME(3) NOT NULL, attempts INT NOT NULL,
PRIMARY KEY(bucket_key,window_start), INDEX idx_rate_expiry(window_start)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS platform_settings (
setting_key VARCHAR(100) PRIMARY KEY, value_json JSON NOT NULL, updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS admin_roles (
user_id INT NOT NULL PRIMARY KEY, role VARCHAR(24) NOT NULL DEFAULT 'owner', granted_by VARCHAR(64) NOT NULL, created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS admin_audit (
id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, action VARCHAR(64) NOT NULL, filters_json JSON NULL, created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, INDEX idx_admin_audit_date(created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS analytics_events (
event_id CHAR(36) PRIMARY KEY, schema_version INT NOT NULL DEFAULT 1, user_id INT NOT NULL, event_type VARCHAR(64) NOT NULL,
session_id CHAR(36) NULL, install_id CHAR(36) NULL, client_platform VARCHAR(12) NOT NULL DEFAULT 'unknown', app_version VARCHAR(32) NULL, app_build VARCHAR(32) NULL,
source_screen VARCHAR(40) NULL, client_occurred_at DATETIME(3) NULL, received_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
significant BOOLEAN NOT NULL DEFAULT FALSE, environment VARCHAR(16) NOT NULL DEFAULT 'production', is_internal BOOLEAN NOT NULL DEFAULT FALSE, metadata_json JSON NULL,
FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
INDEX idx_analytics_time_user(received_at,user_id), INDEX idx_analytics_user_time(user_id,received_at), INDEX idx_analytics_active(significant,received_at,user_id), INDEX idx_analytics_platform(client_platform,received_at), INDEX idx_analytics_type(event_type,received_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS analytics_sessions (
session_id CHAR(36) PRIMARY KEY, user_id INT NOT NULL, client_platform VARCHAR(12) NOT NULL, started_at DATETIME(3) NOT NULL, last_seen_at DATETIME(3) NOT NULL,
FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, INDEX idx_sessions_user_time(user_id,last_seen_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS engagement_events (
id BIGINT AUTO_INCREMENT PRIMARY KEY, event_id CHAR(36) NOT NULL, user_id INT NOT NULL, event_type VARCHAR(64) NOT NULL, source VARCHAR(24) NOT NULL DEFAULT 'database',
idempotency_key VARCHAR(191) NOT NULL, payload_json JSON NULL, occurred_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3), received_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
status VARCHAR(16) NOT NULL DEFAULT 'pending', attempts INT NOT NULL DEFAULT 0, next_attempt_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3), processed_at DATETIME(3) NULL, last_error_code VARCHAR(64) NULL,
FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, UNIQUE KEY uniq_engagement_event(event_id), UNIQUE KEY uniq_engagement_idempotency(user_id,idempotency_key), INDEX idx_outbox_ready(status,next_attempt_at), INDEX idx_engagement_user_time(user_id,occurred_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_momentum (
user_id INT NOT NULL PRIMARY KEY, lifetime_xp INT NOT NULL DEFAULT 0, rhythm INT NOT NULL DEFAULT 0, last_significant_at DATETIME(3) NULL,
last_review_week VARCHAR(10) NULL, last_grace_week VARCHAR(10) NULL, backfilled_at DATETIME(3) NULL, backfill_seen_at DATETIME(3) NULL, coachmark_seen_at DATETIME(3) NULL,
notifications_enabled BOOLEAN NOT NULL DEFAULT FALSE, quiet_start TINYINT NOT NULL DEFAULT 22, quiet_end TINYINT NOT NULL DEFAULT 8, locale VARCHAR(2) NOT NULL DEFAULT 'en',
created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3), updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS momentum_periods (
id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, kind VARCHAR(8) NOT NULL, period_key VARCHAR(10) NOT NULL, timezone_name VARCHAR(64) NOT NULL,
offset_min INT NOT NULL DEFAULT 0, starts_at DATETIME(3) NOT NULL, ends_at DATETIME(3) NOT NULL, assigned_at DATETIME(3) NULL, completed_at DATETIME(3) NULL,
presented_at DATETIME(3) NULL, grace_applied BOOLEAN NOT NULL DEFAULT FALSE, bonus_xp INT NOT NULL DEFAULT 0,
FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, UNIQUE KEY uniq_momentum_period(user_id,kind,period_key), INDEX idx_period_current(user_id,kind,ends_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_missions (
id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, mission_key VARCHAR(80) NOT NULL, catalog_version INT NOT NULL, period_key VARCHAR(10) NOT NULL,
scope VARCHAR(12) NOT NULL, slot VARCHAR(16) NULL, target INT NOT NULL DEFAULT 1, progress INT NOT NULL DEFAULT 0, target_json JSON NULL, status VARCHAR(16) NOT NULL DEFAULT 'active',
nominal_xp INT NOT NULL, granted_xp INT NOT NULL DEFAULT 0, reason_code VARCHAR(64) NULL, assigned_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3), completed_at DATETIME(3) NULL,
FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, UNIQUE KEY uniq_user_mission_period(user_id,mission_key,period_key), INDEX idx_missions_current(user_id,period_key,status), INDEX idx_mission_metrics(mission_key,status,assigned_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mission_replacements (
id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, period_key VARCHAR(10) NOT NULL, old_mission_key VARCHAR(80) NOT NULL,
new_mission_key VARCHAR(80) NULL, reason_code VARCHAR(64) NOT NULL, created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, INDEX idx_replacements_user(user_id,period_key)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_achievement_progress (
user_id INT NOT NULL, achievement_key VARCHAR(80) NOT NULL, progress INT NOT NULL DEFAULT 0, completed_at DATETIME(3) NULL, seen_at DATETIME(3) NULL,
PRIMARY KEY(user_id,achievement_key), FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reward_ledger (
id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, origin VARCHAR(120) NOT NULL, period_key VARCHAR(10) NOT NULL,
cap_group VARCHAR(16) NOT NULL DEFAULT 'none', xp INT NOT NULL, nominal_xp INT NOT NULL, idempotency_key VARCHAR(191) NOT NULL,
compensates_id BIGINT NULL, audit_reason VARCHAR(160) NULL, created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, UNIQUE KEY uniq_reward(user_id,idempotency_key), INDEX idx_reward_cap(user_id,period_key,cap_group), INDEX idx_reward_date(created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS momentum_entities (
user_id INT NOT NULL, entity_type VARCHAR(24) NOT NULL, entity_id BIGINT NOT NULL, canonical_key CHAR(64) NOT NULL,
PRIMARY KEY(user_id,entity_type,entity_id), FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, INDEX idx_entity_canonical(user_id,entity_type,canonical_key)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS momentum_facts (
user_id INT NOT NULL, metric VARCHAR(64) NOT NULL, fact_key VARCHAR(128) NOT NULL, value INT NOT NULL DEFAULT 1, provenance VARCHAR(24) NOT NULL,
created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3), PRIMARY KEY(user_id,metric,fact_key), FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS momentum_review_snapshots (
snapshot_id CHAR(36) PRIMARY KEY, user_id INT NOT NULL, kind VARCHAR(80) NOT NULL, period_key VARCHAR(10) NOT NULL,
evidence_hash CHAR(64) NOT NULL, sections_json JSON NOT NULL, expires_at DATETIME(3) NOT NULL, used_at DATETIME(3) NULL,
FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, INDEX idx_snapshot_user(user_id,expires_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS weekly_reviews (
user_id INT NOT NULL, period_key VARCHAR(10) NOT NULL, timezone_name VARCHAR(64) NOT NULL, checklist_json JSON NOT NULL, next_step VARCHAR(40) NOT NULL,
completed_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3), PRIMARY KEY(user_id,period_key), FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS monthly_reviews (
user_id INT NOT NULL, period_key VARCHAR(10) NOT NULL, timezone_name VARCHAR(64) NOT NULL, checklist_json JSON NOT NULL, next_step VARCHAR(40) NOT NULL,
completed_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3), PRIMARY KEY(user_id,period_key), FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ai_credit_ledger (
id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, credits INT NOT NULL, kind VARCHAR(24) NOT NULL,
idempotency_key VARCHAR(191) NOT NULL, expires_at DATETIME(3) NULL, created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, UNIQUE KEY uniq_credit_ledger(user_id,idempotency_key), INDEX idx_credit_balance(user_id,expires_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ai_credit_reservations (
request_id CHAR(36) PRIMARY KEY, user_id INT NOT NULL, status VARCHAR(16) NOT NULL, uses_credit BOOLEAN NOT NULL, expires_at DATETIME(3) NOT NULL,
response_json JSON NULL, created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3), completed_at DATETIME(3) NULL,
FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE, INDEX idx_credit_reservations(user_id,status,expires_at)
) ENGINE=InnoDB;

INSERT IGNORE INTO platform_settings (setting_key,value_json) VALUES ('tracking_started_at', JSON_OBJECT('at',DATE_FORMAT(UTC_TIMESTAMP(3),'%Y-%m-%dT%H:%i:%s.%fZ')));
