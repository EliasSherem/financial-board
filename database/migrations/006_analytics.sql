CREATE TABLE IF NOT EXISTS analytics_user_settings (
  user_id INT PRIMARY KEY,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  is_internal BOOLEAN NOT NULL DEFAULT FALSE,
  signup_platform VARCHAR(12) NULL,
  environment VARCHAR(16) NOT NULL DEFAULT 'unknown',
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

ALTER TABLE analytics_sessions ADD COLUMN environment VARCHAR(16) NOT NULL DEFAULT 'production';
ALTER TABLE analytics_sessions ADD COLUMN is_internal BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX idx_analytics_cohort ON analytics_events (user_id, significant, client_occurred_at);
CREATE INDEX idx_analytics_environment ON analytics_events (environment, is_internal, received_at);
CREATE INDEX idx_billing_admin ON billing_contracts (provider, status, environment, user_id);
CREATE INDEX idx_billing_history ON billing_state_events (contract_id, occurred_at, effective_access);
