-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE,
    -- Subscription fields (nullable by default)
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

-- Backfill/ensure columns for existing deployments (errors are ok if already exist)
ALTER TABLE users ADD COLUMN is_pro BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN stripe_customer_id VARCHAR(255) NULL;
ALTER TABLE users ADD COLUMN stripe_subscription_id VARCHAR(255) NULL;
ALTER TABLE users ADD COLUMN stripe_subscription_status VARCHAR(50) NULL;
ALTER TABLE users ADD COLUMN stripe_current_period_end DATETIME NULL;
ALTER TABLE users ADD COLUMN timezone_offset_min INT NULL;
ALTER TABLE users ADD COLUMN timezone_name VARCHAR(64) NULL;

-- Create accounts table
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

-- Create projects table
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

-- Create transactions table
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

-- User-defined expense categories
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

-- User-defined expense subcategories
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

-- Backfill monthly budget for subcategories (safe if column already exists)
ALTER TABLE expense_subcategories ADD COLUMN budget DECIMAL(15, 2) NOT NULL DEFAULT 0.00;

-- Upgrade transactions table to reference structured categories
ALTER TABLE transactions ADD COLUMN category_id INT NULL;
ALTER TABLE transactions ADD COLUMN subcategory_id INT NULL;
ALTER TABLE transactions MODIFY COLUMN type ENUM('Income', 'Expense', 'Transfer') NOT NULL;
ALTER TABLE transactions ADD CONSTRAINT fk_transactions_category FOREIGN KEY (category_id) REFERENCES expense_categories(id) ON DELETE SET NULL;
ALTER TABLE transactions ADD CONSTRAINT fk_transactions_subcategory FOREIGN KEY (subcategory_id) REFERENCES expense_subcategories(id) ON DELETE SET NULL;
ALTER TABLE transactions ADD INDEX idx_category_id (category_id);
ALTER TABLE transactions ADD INDEX idx_subcategory_id (subcategory_id);

-- Receipt/ticket scan drafts. These are reviewable drafts only; confirmed
-- transactions are created separately after explicit user approval.
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

-- Create payments table (for recurring payments)
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
    -- Installments support (optional)
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

-- Backfill category references for payments (safe if columns already exist)
ALTER TABLE payments ADD COLUMN category_id INT NULL;
ALTER TABLE payments ADD COLUMN subcategory_id INT NULL;
ALTER TABLE payments ADD INDEX idx_category_id (category_id);
ALTER TABLE payments ADD INDEX idx_subcategory_id (subcategory_id);
ALTER TABLE payments ADD CONSTRAINT fk_payments_category FOREIGN KEY (category_id) REFERENCES expense_categories(id) ON DELETE SET NULL;
ALTER TABLE payments ADD CONSTRAINT fk_payments_subcategory FOREIGN KEY (subcategory_id) REFERENCES expense_subcategories(id) ON DELETE SET NULL;

-- Create sessions table for user authentication
CREATE TABLE IF NOT EXISTS sessions (
    id VARCHAR(255) PRIMARY KEY,
    user_id INT NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_expires_at (expires_at)
);

-- Create balance_history table to track monthly account balances
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

-- Customers table
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

-- Invoices
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

-- Invoice items
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

-- Invoice payments
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

-- Investments: user-declared principal that accrues with daily compounding
CREATE TABLE IF NOT EXISTS investments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(150) NOT NULL,
    principal DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    annual_rate DECIMAL(10,4) NOT NULL DEFAULT 0.0000, -- percent e.g. 8.5
    start_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_start_date (start_date)
);

-- Upgrade: widen annual_rate precision if table already exists
ALTER TABLE investments MODIFY COLUMN annual_rate DECIMAL(10,4) NOT NULL DEFAULT 0.0000;

-- Additional contributions to investments
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

-- Play subscriptions (Google Play Billing) linkage table
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

-- App Store subscriptions linkage table
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

-- Inbound emails received via webhook providers such as Resend
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

-- Salary rules (automated income)
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

-- Device tokens for push notifications
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

-- Notification events (dedupe and state tracking)
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
