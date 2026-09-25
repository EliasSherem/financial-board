-- Non-unique on purpose: ambiguous legacy normalized addresses must remain non-enumerable.
ALTER TABLE users ADD COLUMN email_normalized VARCHAR(100) GENERATED ALWAYS AS (LOWER(TRIM(email))) STORED;
CREATE INDEX idx_users_recovery_email ON users (email_normalized);
