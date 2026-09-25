-- Immutable canonical identity, independent of category/date edits after creation.
-- Equal recreated records share identity; account deletion still removes their financial data.
ALTER TABLE transactions ADD COLUMN momentum_identity CHAR(64) NULL;

-- Preserve the actual last financial edit; assigning an internal identity is not a user edit.
UPDATE transactions SET momentum_identity=SHA2(CONCAT_WS('|',account_id,DATE_FORMAT(date,'%Y-%m-%d'),type,CAST(amount AS CHAR),LOWER(TRIM(description))),256), updated_at=updated_at WHERE momentum_identity IS NULL;

CREATE INDEX idx_transactions_momentum ON transactions(user_id,momentum_identity);

CREATE TRIGGER momentum_transaction_identity_insert BEFORE INSERT ON transactions FOR EACH ROW
SET NEW.momentum_identity=SHA2(CONCAT_WS('|',NEW.account_id,DATE_FORMAT(NEW.date,'%Y-%m-%d'),NEW.type,CAST(NEW.amount AS CHAR),LOWER(TRIM(NEW.description))),256);

CREATE TRIGGER momentum_transaction_identity_update BEFORE UPDATE ON transactions FOR EACH ROW
SET NEW.momentum_identity=OLD.momentum_identity;
