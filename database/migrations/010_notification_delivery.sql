ALTER TABLE device_tokens MODIFY token VARCHAR(1024) CHARACTER SET ascii COLLATE ascii_bin NOT NULL;

CREATE TABLE IF NOT EXISTS notification_deliveries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  event_id INT NOT NULL,
  token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  status ENUM('pending','leased','accepted','retryable','invalid','rejected','unknown','expired') NOT NULL DEFAULT 'pending',
  attempts INT NOT NULL DEFAULT 0,
  lease_token CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  lease_until DATETIME(3) NULL,
  next_attempt_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at DATETIME(3) NOT NULL,
  last_code VARCHAR(64) NULL,
  accepted_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  UNIQUE KEY uniq_notification_device(event_id,token_hash),
  INDEX idx_notification_delivery_due(status,next_attempt_at),
  CONSTRAINT fk_notification_delivery_event FOREIGN KEY(event_id) REFERENCES notification_events(id) ON DELETE CASCADE
);
