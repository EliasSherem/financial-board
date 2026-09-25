-- Explicit legacy baseline, without demo users or runtime DDL.
-- Existing columns/keys are checked before additive upgrades; no errors are silently ignored.

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE,
    
    is_pro BOOLEAN DEFAULT FALSE,
    stripe_customer_id VARCHAR(255) NULL,
    stripe_subscription_id VARCHAR(255) NULL,
    stripe_subscription_status VARCHAR(50) NULL,
    stripe_current_period_end DATETIME NULL,
    timezone_offset_min INT NULL,
    timezone_name VARCHAR(64) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE users ADD COLUMN is_pro BOOLEAN DEFAULT FALSE','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='is_pro');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE users ADD COLUMN stripe_customer_id VARCHAR(255) NULL','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='stripe_customer_id');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE users ADD COLUMN stripe_subscription_id VARCHAR(255) NULL','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='stripe_subscription_id');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE users ADD COLUMN stripe_subscription_status VARCHAR(50) NULL','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='stripe_subscription_status');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE users ADD COLUMN stripe_current_period_end DATETIME NULL','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='stripe_current_period_end');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE users ADD COLUMN timezone_offset_min INT NULL','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='timezone_offset_min');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE users ADD COLUMN timezone_name VARCHAR(64) NULL','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='timezone_name');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

CREATE TABLE IF NOT EXISTS accounts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    type ENUM('Checking', 'Savings', 'Business', 'Investment', 'Credit') NOT NULL,
    balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    account_number VARCHAR(20),
    bank_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id)
);

CREATE TABLE IF NOT EXISTS projects (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    budget DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    spent DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    status ENUM('Active', 'Completed', 'On Hold') NOT NULL DEFAULT 'Active',
    start_date DATE,
    end_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_status (status)
);

CREATE TABLE IF NOT EXISTS transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    account_id INT NOT NULL,
    project_id INT,
    date DATE NOT NULL,
    description VARCHAR(255) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    type ENUM('Income', 'Expense', 'Transfer') NOT NULL,
    category VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_account_id (account_id),
    INDEX idx_project_id (project_id),
    INDEX idx_date (date),
    INDEX idx_type (type)
);

CREATE TABLE IF NOT EXISTS expense_categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(64) NOT NULL DEFAULT 'category',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uniq_user_category (user_id, name),
    INDEX idx_user (user_id)
);

CREATE TABLE IF NOT EXISTS expense_subcategories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    category_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(64) NOT NULL DEFAULT 'subcategory',
    budget DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES expense_categories(id) ON DELETE CASCADE,
    UNIQUE KEY uniq_user_subcategory (user_id, category_id, name),
    INDEX idx_user (user_id),
    INDEX idx_category (category_id)
);

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE expense_subcategories ADD COLUMN budget DECIMAL(15, 2) NOT NULL DEFAULT 0.00','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='expense_subcategories' AND COLUMN_NAME='budget');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE transactions ADD COLUMN category_id INT NULL','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='transactions' AND COLUMN_NAME='category_id');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE transactions ADD COLUMN subcategory_id INT NULL','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='transactions' AND COLUMN_NAME='subcategory_id');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

ALTER TABLE transactions MODIFY COLUMN type ENUM('Income', 'Expense', 'Transfer') NOT NULL;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE transactions ADD CONSTRAINT fk_transactions_category FOREIGN KEY (category_id) REFERENCES expense_categories(id) ON DELETE SET NULL','SELECT 1') FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='transactions' AND CONSTRAINT_NAME='fk_transactions_category');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE transactions ADD CONSTRAINT fk_transactions_subcategory FOREIGN KEY (subcategory_id) REFERENCES expense_subcategories(id) ON DELETE SET NULL','SELECT 1') FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='transactions' AND CONSTRAINT_NAME='fk_transactions_subcategory');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE transactions ADD INDEX idx_category_id (category_id)','SELECT 1') FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='transactions' AND INDEX_NAME='idx_category_id');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE transactions ADD INDEX idx_subcategory_id (subcategory_id)','SELECT 1') FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='transactions' AND INDEX_NAME='idx_subcategory_id');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

CREATE TABLE IF NOT EXISTS transaction_drafts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'processing',
    account_id INT NULL,
    project_id INT NULL,
    date DATE NULL,
    description VARCHAR(255) NULL,
    amount DECIMAL(12, 2) NULL,
    type VARCHAR(32) NULL,
    category VARCHAR(100) NULL,
    category_id INT NULL,
    subcategory_id INT NULL,
    payment_method VARCHAR(32) NULL,
    currency VARCHAR(8) NULL DEFAULT 'MXN',
    notes TEXT NULL,
    confidence DECIMAL(5, 4) NULL,
    extraction_json JSON NULL,
    warnings_json JSON NULL,
    image_sha256 VARCHAR(64) NULL,
    image_mime VARCHAR(100) NULL,
    image_size_bytes INT NULL,
    error_message TEXT NULL,
    confirmed_transaction_id INT NULL,
    confirmed_at DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_transaction_drafts_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_transaction_drafts_account FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE SET NULL,
    CONSTRAINT fk_transaction_drafts_project FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL,
    CONSTRAINT fk_transaction_drafts_category FOREIGN KEY (category_id) REFERENCES expense_categories(id) ON DELETE SET NULL,
    CONSTRAINT fk_transaction_drafts_subcategory FOREIGN KEY (subcategory_id) REFERENCES expense_subcategories(id) ON DELETE SET NULL,
    CONSTRAINT fk_transaction_drafts_confirmed_transaction FOREIGN KEY (confirmed_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL,
    INDEX idx_transaction_drafts_user_status (user_id, status),
    INDEX idx_transaction_drafts_user_created (user_id, created_at),
    INDEX idx_transaction_drafts_image_sha256 (image_sha256),
    INDEX idx_transaction_drafts_confirmed_transaction_id (confirmed_transaction_id),
    INDEX idx_transaction_drafts_account_id (account_id),
    INDEX idx_transaction_drafts_project_id (project_id),
    INDEX idx_transaction_drafts_category_id (category_id),
    INDEX idx_transaction_drafts_subcategory_id (subcategory_id)
);

CREATE TABLE IF NOT EXISTS payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    account_id INT NOT NULL,
    project_id INT,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    amount DECIMAL(15, 2) NOT NULL,
    frequency ENUM('Weekly', 'Monthly', 'Quarterly', 'Yearly') NOT NULL,
    next_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    category VARCHAR(50),
    category_id INT NULL,
    subcategory_id INT NULL,
    
    installments_total INT NULL,
    installments_remaining INT NULL,
    installment_total_amount DECIMAL(15, 2) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL,
    FOREIGN KEY (category_id) REFERENCES expense_categories(id) ON DELETE SET NULL,
    FOREIGN KEY (subcategory_id) REFERENCES expense_subcategories(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_next_date (next_date),
    INDEX idx_is_active (is_active),
    INDEX idx_project_id (project_id),
    INDEX idx_category_id (category_id),
    INDEX idx_subcategory_id (subcategory_id)
);

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE payments ADD COLUMN category_id INT NULL','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='payments' AND COLUMN_NAME='category_id');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE payments ADD COLUMN subcategory_id INT NULL','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='payments' AND COLUMN_NAME='subcategory_id');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE payments ADD INDEX idx_category_id (category_id)','SELECT 1') FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='payments' AND INDEX_NAME='idx_category_id');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE payments ADD INDEX idx_subcategory_id (subcategory_id)','SELECT 1') FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='payments' AND INDEX_NAME='idx_subcategory_id');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE payments ADD CONSTRAINT fk_payments_category FOREIGN KEY (category_id) REFERENCES expense_categories(id) ON DELETE SET NULL','SELECT 1') FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='payments' AND CONSTRAINT_NAME='fk_payments_category');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE payments ADD CONSTRAINT fk_payments_subcategory FOREIGN KEY (subcategory_id) REFERENCES expense_subcategories(id) ON DELETE SET NULL','SELECT 1') FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='payments' AND CONSTRAINT_NAME='fk_payments_subcategory');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

CREATE TABLE IF NOT EXISTS sessions (
    id VARCHAR(255) PRIMARY KEY,
    user_id INT NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_expires_at (expires_at)
);

CREATE TABLE IF NOT EXISTS balance_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    account_id INT NOT NULL,
    year INT NOT NULL,
    month INT NOT NULL,
    balance DECIMAL(15, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    UNIQUE KEY unique_account_month (account_id, year, month),
    INDEX idx_user_id (user_id),
    INDEX idx_account_id (account_id),
    INDEX idx_year_month (year, month)
);

CREATE TABLE IF NOT EXISTS customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(150),
    company VARCHAR(150),
    tax_id VARCHAR(50),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id)
);

CREATE TABLE IF NOT EXISTS invoices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    customer_id INT NOT NULL,
    project_id INT NULL,
    account_id INT NULL,
    number VARCHAR(50),
    issue_date DATE NOT NULL,
    due_date DATE NOT NULL,
    status ENUM('draft','sent','partial','paid','void') NOT NULL DEFAULT 'draft',
    currency VARCHAR(8) DEFAULT 'MXN',
    notes TEXT,
    subtotal DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    tax DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    discount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    total DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    amount_due DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE RESTRICT,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_customer_id (customer_id),
    INDEX idx_status (status),
    INDEX idx_issue_date (issue_date)
);

CREATE TABLE IF NOT EXISTS invoice_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT NOT NULL,
    description VARCHAR(255) NOT NULL,
    quantity DECIMAL(15,2) NOT NULL DEFAULT 1.00,
    unit_price DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
    INDEX idx_invoice_id (invoice_id)
);

CREATE TABLE IF NOT EXISTS invoice_payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT NOT NULL,
    date DATE NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    account_id INT NOT NULL,
    method VARCHAR(50),
    reference VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    INDEX idx_invoice_id (invoice_id),
    INDEX idx_date (date)
);

CREATE TABLE IF NOT EXISTS investments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(150) NOT NULL,
    principal DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    annual_rate DECIMAL(10,4) NOT NULL DEFAULT 0.0000, 
    start_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_start_date (start_date)
);

ALTER TABLE investments MODIFY COLUMN annual_rate DECIMAL(10,4) NOT NULL DEFAULT 0.0000;

CREATE TABLE IF NOT EXISTS investment_contributions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    investment_id INT NOT NULL,
    amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (investment_id) REFERENCES investments(id) ON DELETE CASCADE,
    INDEX idx_user (user_id),
    INDEX idx_investment (investment_id),
    INDEX idx_date (date)
);

CREATE TABLE IF NOT EXISTS play_subscriptions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id VARCHAR(128) NOT NULL,
    purchase_token VARCHAR(512) NOT NULL,
    auto_renewing BOOLEAN,
    expiry_time DATETIME NULL,
    last_state VARCHAR(64),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uniq_token (purchase_token),
    INDEX idx_user (user_id)
);

CREATE TABLE IF NOT EXISTS app_store_subscriptions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id VARCHAR(128) NOT NULL,
    original_transaction_id VARCHAR(128) NOT NULL,
    latest_transaction_id VARCHAR(128) NULL,
    auto_renew_status BOOLEAN NULL,
    expiry_time DATETIME NULL,
    last_state VARCHAR(64) NULL,
    environment VARCHAR(32) NULL,
    receipt_data MEDIUMTEXT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uniq_original_transaction (original_transaction_id),
    INDEX idx_user (user_id)
);

CREATE TABLE IF NOT EXISTS inbound_emails (
    id INT AUTO_INCREMENT PRIMARY KEY,
    provider VARCHAR(32) NOT NULL DEFAULT 'resend',
    event_type VARCHAR(64) NOT NULL,
    provider_email_id VARCHAR(128) NULL,
    sender VARCHAR(255) NULL,
    subject VARCHAR(255) NULL,
    message_id VARCHAR(255) NULL,
    to_addresses JSON NULL,
    cc_addresses JSON NULL,
    bcc_addresses JSON NULL,
    html LONGTEXT NULL,
    text LONGTEXT NULL,
    headers_json LONGTEXT NULL,
    attachments_json LONGTEXT NULL,
    raw_download_url TEXT NULL,
    payload_json LONGTEXT NOT NULL,
    provider_created_at DATETIME NULL,
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_provider_email (provider, provider_email_id),
    INDEX idx_event_type (event_type),
    INDEX idx_received_at (received_at)
);

CREATE TABLE IF NOT EXISTS salary_rules (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    schedule ENUM('Weekly','Monthly','SemiMonthly') NOT NULL DEFAULT 'SemiMonthly',
    weekday TINYINT NULL,
    day TINYINT NULL,
    account_id INT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    next_date DATE NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user (user_id)
);

CREATE TABLE IF NOT EXISTS device_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token VARCHAR(255) NOT NULL,
    platform VARCHAR(32) NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uniq_user_token (user_id, token),
    INDEX idx_user (user_id)
);

CREATE TABLE IF NOT EXISTS notification_events (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    type VARCHAR(64) NOT NULL,
    entity_id VARCHAR(64) NOT NULL,
    event_key VARCHAR(64) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at DATETIME NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uniq_user_type_entity_event (user_id, type, entity_id, event_key),
    INDEX idx_user_type (user_id, type)
);

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE investments ADD COLUMN account_id INT NULL','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='investments' AND COLUMN_NAME='account_id');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE investment_contributions ADD COLUMN transaction_id INT NULL','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='investment_contributions' AND COLUMN_NAME='transaction_id');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE salary_rules ADD COLUMN next_date DATE NULL','SELECT 1') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='salary_rules' AND COLUMN_NAME='next_date');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE investments ADD UNIQUE KEY uniq_investment_account (account_id)','SELECT 1') FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='investments' AND INDEX_NAME='uniq_investment_account');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE investment_contributions ADD UNIQUE KEY uniq_investment_contribution_tx (transaction_id)','SELECT 1') FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='investment_contributions' AND INDEX_NAME='uniq_investment_contribution_tx');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;

SET @finsight_ddl = (SELECT IF(COUNT(*)=0,'ALTER TABLE investments ADD CONSTRAINT fk_investments_account FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE SET NULL','SELECT 1') FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='investments' AND CONSTRAINT_NAME='fk_investments_account');
PREPARE finsight_stmt FROM @finsight_ddl;
EXECUTE finsight_stmt;
DEALLOCATE PREPARE finsight_stmt;
