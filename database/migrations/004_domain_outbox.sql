-- Domain outbox: each INSERT is part of the same financial statement/transaction.
-- No evaluator or network runs inside triggers. A failed outbox write fails its financial write.
-- These triggers capture legacy paths as well as current REST clients.

CREATE TRIGGER momentum_accounts_insert AFTER INSERT ON accounts FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'accounts.insert','database',UUID(),JSON_OBJECT('entity_id',NEW.id);

CREATE TRIGGER momentum_accounts_update AFTER UPDATE ON accounts FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'accounts.update','database',UUID(),JSON_OBJECT('entity_id',NEW.id) WHERE NOT (OLD.is_active <=> NEW.is_active) OR NOT (OLD.name <=> NEW.name) OR NOT (OLD.type <=> NEW.type);

CREATE TRIGGER momentum_accounts_delete AFTER DELETE ON accounts FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),OLD.user_id,'accounts.delete','database',UUID(),JSON_OBJECT('entity_id',OLD.id);

CREATE TRIGGER momentum_transactions_insert AFTER INSERT ON transactions FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'transactions.insert','database',UUID(),JSON_OBJECT('entity_id',NEW.id,'canonical_key',SHA2(CONCAT_WS('|',NEW.account_id,DATE_FORMAT(NEW.date,'%Y-%m-%d'),NEW.type,CAST(NEW.amount AS CHAR),LOWER(TRIM(NEW.description))),256),'categorized',IF(NEW.category_id IS NOT NULL OR NULLIF(TRIM(NEW.category),'') IS NOT NULL,1,0),'subcategory_id',NEW.subcategory_id,'transaction_type',NEW.type);

CREATE TRIGGER momentum_transactions_update AFTER UPDATE ON transactions FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'transactions.update','database',UUID(),JSON_OBJECT('entity_id',NEW.id,'canonical_key',SHA2(CONCAT_WS('|',NEW.account_id,DATE_FORMAT(NEW.date,'%Y-%m-%d'),NEW.type,CAST(NEW.amount AS CHAR),LOWER(TRIM(NEW.description))),256),'categorized',IF(NEW.category_id IS NOT NULL OR NULLIF(TRIM(NEW.category),'') IS NOT NULL,1,0),'subcategory_id',NEW.subcategory_id,'transaction_type',NEW.type) WHERE NOT (OLD.category_id <=> NEW.category_id) OR NOT (OLD.subcategory_id <=> NEW.subcategory_id) OR NOT (OLD.category <=> NEW.category) OR NOT (OLD.date <=> NEW.date) OR NOT (OLD.amount <=> NEW.amount) OR NOT (OLD.description <=> NEW.description);

CREATE TRIGGER momentum_transactions_delete AFTER DELETE ON transactions FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),OLD.user_id,'transactions.delete','database',UUID(),JSON_OBJECT('entity_id',OLD.id,'canonical_key',SHA2(CONCAT_WS('|',OLD.account_id,DATE_FORMAT(OLD.date,'%Y-%m-%d'),OLD.type,CAST(OLD.amount AS CHAR),LOWER(TRIM(OLD.description))),256),'categorized',IF(OLD.category_id IS NOT NULL OR NULLIF(TRIM(OLD.category),'') IS NOT NULL,1,0),'subcategory_id',OLD.subcategory_id,'transaction_type',OLD.type);

CREATE TRIGGER momentum_expense_categories_insert AFTER INSERT ON expense_categories FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'expense_categories.insert','database',UUID(),JSON_OBJECT('entity_id',NEW.id);

CREATE TRIGGER momentum_expense_categories_update AFTER UPDATE ON expense_categories FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'expense_categories.update','database',UUID(),JSON_OBJECT('entity_id',NEW.id) WHERE NOT (OLD.name <=> NEW.name) OR NOT (OLD.icon <=> NEW.icon);

CREATE TRIGGER momentum_expense_categories_delete AFTER DELETE ON expense_categories FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),OLD.user_id,'expense_categories.delete','database',UUID(),JSON_OBJECT('entity_id',OLD.id);

CREATE TRIGGER momentum_expense_subcategories_insert AFTER INSERT ON expense_subcategories FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'expense_subcategories.insert','database',UUID(),JSON_OBJECT('entity_id',NEW.id);

CREATE TRIGGER momentum_expense_subcategories_update AFTER UPDATE ON expense_subcategories FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'expense_subcategories.update','database',UUID(),JSON_OBJECT('entity_id',NEW.id) WHERE NOT (OLD.name <=> NEW.name) OR NOT (OLD.category_id <=> NEW.category_id) OR NOT (OLD.budget <=> NEW.budget);

CREATE TRIGGER momentum_expense_subcategories_delete AFTER DELETE ON expense_subcategories FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),OLD.user_id,'expense_subcategories.delete','database',UUID(),JSON_OBJECT('entity_id',OLD.id);

CREATE TRIGGER momentum_payments_insert AFTER INSERT ON payments FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'payments.insert','database',UUID(),JSON_OBJECT('entity_id',NEW.id);

CREATE TRIGGER momentum_payments_update AFTER UPDATE ON payments FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'payments.update','database',UUID(),JSON_OBJECT('entity_id',NEW.id,'previous_date',DATE_FORMAT(OLD.next_date,'%Y-%m-%d'),'next_date',DATE_FORMAT(NEW.next_date,'%Y-%m-%d'),'active',NEW.is_active) WHERE NOT (OLD.next_date <=> NEW.next_date) OR NOT (OLD.is_active <=> NEW.is_active) OR NOT (OLD.frequency <=> NEW.frequency);

CREATE TRIGGER momentum_payments_delete AFTER DELETE ON payments FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),OLD.user_id,'payments.delete','database',UUID(),JSON_OBJECT('entity_id',OLD.id);

CREATE TRIGGER momentum_projects_insert AFTER INSERT ON projects FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'projects.insert','database',UUID(),JSON_OBJECT('entity_id',NEW.id,'status',NEW.status);

CREATE TRIGGER momentum_projects_update AFTER UPDATE ON projects FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'projects.update','database',UUID(),JSON_OBJECT('entity_id',NEW.id,'status',NEW.status) WHERE NOT (OLD.status <=> NEW.status) OR NOT (OLD.end_date <=> NEW.end_date) OR NOT (OLD.description <=> NEW.description);

CREATE TRIGGER momentum_projects_delete AFTER DELETE ON projects FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),OLD.user_id,'projects.delete','database',UUID(),JSON_OBJECT('entity_id',OLD.id,'status',OLD.status);

CREATE TRIGGER momentum_invoices_insert AFTER INSERT ON invoices FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'invoices.insert','database',UUID(),JSON_OBJECT('entity_id',NEW.id);

CREATE TRIGGER momentum_invoices_update AFTER UPDATE ON invoices FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'invoices.update','database',UUID(),JSON_OBJECT('entity_id',NEW.id) WHERE NOT (OLD.status <=> NEW.status) OR NOT (OLD.amount_due <=> NEW.amount_due);

CREATE TRIGGER momentum_invoices_delete AFTER DELETE ON invoices FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),OLD.user_id,'invoices.delete','database',UUID(),JSON_OBJECT('entity_id',OLD.id);

CREATE TRIGGER momentum_investments_insert AFTER INSERT ON investments FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'investments.insert','database',UUID(),JSON_OBJECT('entity_id',NEW.id);

CREATE TRIGGER momentum_investments_update AFTER UPDATE ON investments FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'investments.update','database',UUID(),JSON_OBJECT('entity_id',NEW.id) WHERE NOT (OLD.name <=> NEW.name) OR NOT (OLD.annual_rate <=> NEW.annual_rate) OR NOT (OLD.start_date <=> NEW.start_date);

CREATE TRIGGER momentum_investments_delete AFTER DELETE ON investments FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),OLD.user_id,'investments.delete','database',UUID(),JSON_OBJECT('entity_id',OLD.id);

CREATE TRIGGER momentum_transaction_drafts_insert AFTER INSERT ON transaction_drafts FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'transaction_drafts.insert','database',UUID(),JSON_OBJECT('entity_id',NEW.id,'status',NEW.status,'image_hash',NEW.image_sha256);

CREATE TRIGGER momentum_transaction_drafts_update AFTER UPDATE ON transaction_drafts FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),NEW.user_id,'transaction_drafts.update','database',UUID(),JSON_OBJECT('entity_id',NEW.id,'status',NEW.status,'image_hash',NEW.image_sha256) WHERE NOT (OLD.status <=> NEW.status);

CREATE TRIGGER momentum_transaction_drafts_delete AFTER DELETE ON transaction_drafts FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),OLD.user_id,'transaction_drafts.delete','database',UUID(),JSON_OBJECT('entity_id',OLD.id,'status',OLD.status,'image_hash',OLD.image_sha256);

CREATE TRIGGER momentum_invoice_payments_insert AFTER INSERT ON invoice_payments FOR EACH ROW
INSERT INTO engagement_events (event_id,user_id,event_type,source,idempotency_key,payload_json)
SELECT UUID(),i.user_id,'invoice_payments.insert','database',UUID(),JSON_OBJECT('entity_id',NEW.id,'invoice_id',NEW.invoice_id) FROM invoices i WHERE i.id=NEW.invoice_id;

CREATE TRIGGER reward_ledger_no_update BEFORE UPDATE ON reward_ledger FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Reward ledger is append-only; use an audited compensation';

CREATE TRIGGER reward_ledger_no_delete BEFORE DELETE ON reward_ledger FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Reward ledger deletion is only allowed by user cascade';
