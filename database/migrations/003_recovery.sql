-- Apply once through the migration runner, before deploying authentication code.
-- Never infer a legacy user's identity provider from a bcrypt hash or email.
ALTER TABLE users ADD COLUMN credential_kind ENUM('unknown','local','google') NOT NULL DEFAULT 'unknown';
ALTER TABLE users ADD COLUMN token_version INT UNSIGNED NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS password_reset_tokens (
  token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  user_id INT NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  created_at DATETIME(3) NOT NULL,
  consumed_at DATETIME(3) NULL,
  invalidated_at DATETIME(3) NULL,
  INDEX idx_reset_user (user_id, created_at),
  INDEX idx_reset_expiry (expires_at),
  CONSTRAINT fk_reset_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS auth_rate_limits (
  subject_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  window_started_at DATETIME(3) NOT NULL,
  last_attempt_at DATETIME(3) NOT NULL,
  attempts INT UNSIGNED NOT NULL,
  INDEX idx_auth_rate_retention (last_attempt_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS auth_security_audit (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT NULL,
  event_type VARCHAR(48) NOT NULL,
  received_at DATETIME(3) NOT NULL,
  INDEX idx_auth_audit_time (received_at),
  INDEX idx_auth_audit_user (user_id, received_at),
  CONSTRAINT fk_auth_audit_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;
