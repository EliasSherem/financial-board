-- Additive; apply with the migration runner, never through application startup.
CREATE TABLE IF NOT EXISTS billing_contracts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  provider VARCHAR(16) NOT NULL,
  contract_key VARCHAR(191) NOT NULL,
  product_id VARCHAR(128) NOT NULL,
  base_plan_id VARCHAR(128) NULL,
  raw_state VARCHAR(80) NOT NULL,
  status VARCHAR(32) NOT NULL,
  access_until DATETIME(3) NULL,
  is_trial BOOLEAN NOT NULL DEFAULT FALSE,
  auto_renewing BOOLEAN NULL,
  currency CHAR(3) NULL,
  recurring_amount DECIMAL(20,6) NULL,
  period_months DECIMAL(12,6) NULL,
  environment VARCHAR(16) NOT NULL DEFAULT 'unknown',
  verified BOOLEAN NOT NULL DEFAULT FALSE,
  synced_at DATETIME(3) NULL, checkout_flow_id CHAR(36) NULL,
  replaced_by_id BIGINT UNSIGNED NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  UNIQUE KEY billing_contract_identity(provider,contract_key),
  INDEX billing_user(user_id,status,access_until),
  INDEX billing_sync(synced_at),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS billing_grants (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  source VARCHAR(64) NOT NULL,
  expires_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY billing_grant_identity(user_id,source),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
-- These are the two documented, existing exemptions; they are NOT admin roles.
INSERT IGNORE INTO billing_grants(user_id,source) SELECT id,'legacy_code_exemption' FROM users WHERE id IN (1,3);
-- Preserve unattributed existing Pro during an explicit, time-bounded operator classification.
-- Never report this as a paid subscription or silently extend it on application startup.
INSERT IGNORE INTO billing_grants(user_id,source,expires_at)
 SELECT u.id,'legacy_unknown',DATE_ADD(UTC_TIMESTAMP(3),INTERVAL 30 DAY) FROM users u
 WHERE u.is_pro=TRUE AND u.id NOT IN (1,3) AND u.stripe_subscription_id IS NULL
 AND NOT EXISTS(SELECT 1 FROM play_subscriptions p WHERE p.user_id=u.id)
 AND NOT EXISTS(SELECT 1 FROM app_store_subscriptions a WHERE a.user_id=u.id);
CREATE TABLE IF NOT EXISTS billing_purchase_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  contract_id BIGINT UNSIGNED NOT NULL,
  provider VARCHAR(16) NOT NULL,
  token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  secret_encrypted MEDIUMTEXT NOT NULL,
  product_id VARCHAR(128) NOT NULL,
  acknowledged BOOLEAN NOT NULL DEFAULT FALSE,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY billing_token_identity(provider,token_hash),
  INDEX billing_token_user(user_id),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(contract_id) REFERENCES billing_contracts(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS billing_inbox (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  provider VARCHAR(16) NOT NULL,
  event_key VARCHAR(191) NOT NULL,
  user_id INT NULL,
  payload_encrypted MEDIUMTEXT NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'pending',
  attempts INT NOT NULL DEFAULT 0,
  next_attempt_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  lease_until DATETIME(3) NULL,
  last_error_code VARCHAR(64) NULL,
  received_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  processed_at DATETIME(3) NULL,
  UNIQUE KEY billing_event_identity(provider,event_key),
  INDEX billing_inbox_due(status,next_attempt_at,lease_until),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS billing_jobs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  job_key VARCHAR(191) NOT NULL,
  kind VARCHAR(32) NOT NULL,
  token_id BIGINT UNSIGNED NULL, order_id VARCHAR(191) NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'pending',
  attempts INT NOT NULL DEFAULT 0,
  next_attempt_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  lease_until DATETIME(3) NULL,
  last_error_code VARCHAR(64) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  completed_at DATETIME(3) NULL,
  UNIQUE KEY billing_job_identity(job_key),
  INDEX billing_job_due(status,next_attempt_at,lease_until),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(token_id) REFERENCES billing_purchase_tokens(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS billing_charges (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  contract_id BIGINT UNSIGNED NOT NULL,
  provider VARCHAR(16) NOT NULL,
  provider_charge_id VARCHAR(191) NOT NULL,
  kind VARCHAR(16) NOT NULL,
  amount DECIMAL(20,6) NOT NULL,
  currency CHAR(3) NOT NULL,
  occurred_at DATETIME(3) NOT NULL,
  environment VARCHAR(16) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY billing_charge_identity(provider,provider_charge_id,kind),
  INDEX billing_revenue(occurred_at,currency,environment),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(contract_id) REFERENCES billing_contracts(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS billing_state_events (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  contract_id BIGINT UNSIGNED NOT NULL,
  provider VARCHAR(16) NOT NULL,
  previous_status VARCHAR(32) NULL,
  status VARCHAR(32) NOT NULL,
  effective_access BOOLEAN NOT NULL, access_until DATETIME(3) NULL,
  occurred_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX billing_state_timeline(user_id,occurred_at),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(contract_id) REFERENCES billing_contracts(id) ON DELETE CASCADE
) ENGINE=InnoDB;
-- Legacy records retain their provenance and are reconciled with the provider.
-- No guessed revenue, trial, platform, or historical verification is generated.
INSERT IGNORE INTO billing_contracts(user_id,provider,contract_key,product_id,raw_state,status,access_until,environment,verified)
 SELECT user_id,'google',SHA2(purchase_token,256),product_id,COALESCE(last_state,'UNKNOWN'),'legacy',expiry_time,'unknown',FALSE FROM play_subscriptions;
INSERT IGNORE INTO billing_contracts(user_id,provider,contract_key,product_id,raw_state,status,access_until,environment,verified)
 SELECT user_id,'apple',original_transaction_id,product_id,COALESCE(last_state,'UNKNOWN'),'legacy',expiry_time,IF(environment='Sandbox','test','production'),FALSE FROM app_store_subscriptions;
INSERT IGNORE INTO billing_contracts(user_id,provider,contract_key,product_id,raw_state,status,access_until,environment,verified)
 SELECT id,'stripe',stripe_subscription_id,'legacy',COALESCE(stripe_subscription_status,'unknown'),'legacy',stripe_current_period_end,'unknown',FALSE FROM users WHERE stripe_subscription_id IS NOT NULL;
