-- Opaque provider identifiers are case-sensitive. Keep table defaults for human text.
-- Additive upgrade: preserve column lengths, nullability and existing unique indexes.
ALTER TABLE billing_contracts MODIFY COLUMN contract_key VARCHAR(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL;
ALTER TABLE billing_inbox MODIFY COLUMN event_key VARCHAR(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL;
ALTER TABLE billing_jobs MODIFY COLUMN job_key VARCHAR(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL;
ALTER TABLE billing_charges MODIFY COLUMN provider_charge_id VARCHAR(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL;
-- Legacy ownership lookups and updates still use this column during reconciliation.
ALTER TABLE play_subscriptions MODIFY COLUMN purchase_token VARCHAR(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL;
