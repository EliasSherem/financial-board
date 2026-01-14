-- Insert root user (password: admin)
-- Note: In production, use proper password hashing. This uses bcrypt hash for 'admin'
INSERT INTO users (username, password, email) VALUES 
('root', '$2b$10$AG4n4SvmRC7IONPa.wVqAe/Kz/qfOLuBly50Anh49QJaRhEX4dffe', 'root@example.com');

-- Get the root user ID for subsequent inserts
SET @root_user_id = LAST_INSERT_ID();

-- Insert sample accounts for root user
INSERT INTO accounts (user_id, name, type, balance, account_number, bank_name, is_active) VALUES
(@root_user_id, 'Main Checking', 'Checking', 5420.00, '****1234', 'First National Bank', TRUE),
(@root_user_id, 'Savings Account', 'Savings', 12300.50, '****5678', 'First National Bank', TRUE),
(@root_user_id, 'Business Account', 'Business', 8750.25, '****9012', 'Business Bank', TRUE),
(@root_user_id, 'Investment Portfolio', 'Investment', 45200.00, '****3456', 'Investment Corp', TRUE),
(@root_user_id, 'Credit Card', 'Credit', -2150.75, '****7890', 'Credit Union', TRUE);

-- Get account IDs for transactions
SET @checking_id = (SELECT id FROM accounts WHERE user_id = @root_user_id AND name = 'Main Checking');
SET @savings_id = (SELECT id FROM accounts WHERE user_id = @root_user_id AND name = 'Savings Account');
SET @business_id = (SELECT id FROM accounts WHERE user_id = @root_user_id AND name = 'Business Account');
SET @credit_id = (SELECT id FROM accounts WHERE user_id = @root_user_id AND name = 'Credit Card');

-- Insert sample projects for root user
INSERT INTO projects (user_id, name, description, budget, spent, status, start_date, end_date) VALUES
(@root_user_id, 'Website Redesign', 'Complete overhaul of company website', 15000.00, 8500.00, 'Active', '2025-07-01', '2025-09-30'),
(@root_user_id, 'Mobile App Development', 'Native iOS and Android app', 25000.00, 25000.00, 'Completed', '2025-01-15', '2025-06-30'),
(@root_user_id, 'Marketing Campaign', 'Q3 digital marketing initiative', 8000.00, 3200.00, 'On Hold', '2025-08-01', '2025-10-31'),
(@root_user_id, 'Office Renovation', 'Modernize office space', 20000.00, 5000.00, 'Active', '2025-08-15', '2025-12-31');

-- Get project IDs
SET @website_project_id = (SELECT id FROM projects WHERE user_id = @root_user_id AND name = 'Website Redesign');
SET @marketing_project_id = (SELECT id FROM projects WHERE user_id = @root_user_id AND name = 'Marketing Campaign');

-- Insert sample transactions for root user
INSERT INTO transactions (user_id, account_id, project_id, date, description, amount, type, category) VALUES
(@root_user_id, @checking_id, NULL, DATE_SUB(CURDATE(), INTERVAL 1 DAY), 'Grocery Store', -85.42, 'Expense', 'Food & Dining'),
(@root_user_id, @checking_id, NULL, DATE_SUB(CURDATE(), INTERVAL 2 DAY), 'Salary Deposit', 3500.00, 'Income', 'Salary'),
(@root_user_id, @checking_id, NULL, DATE_SUB(CURDATE(), INTERVAL 3 DAY), 'Electric Bill', -120.30, 'Expense', 'Bills & Utilities'),
(@root_user_id, @business_id, @website_project_id, DATE_SUB(CURDATE(), INTERVAL 4 DAY), 'Web Developer Payment', -1200.00, 'Expense', 'Freelance'),
(@root_user_id, @business_id, NULL, DATE_SUB(CURDATE(), INTERVAL 5 DAY), 'Client Payment', 2500.00, 'Income', 'Freelance'),
(@root_user_id, @credit_id, NULL, DATE_SUB(CURDATE(), INTERVAL 6 DAY), 'Restaurant', -65.50, 'Expense', 'Food & Dining'),
(@root_user_id, @checking_id, NULL, DATE_SUB(CURDATE(), INTERVAL 7 DAY), 'Gas Station', -45.00, 'Expense', 'Transportation'),
(@root_user_id, @savings_id, NULL, DATE_SUB(CURDATE(), INTERVAL 8 DAY), 'Interest Payment', 25.50, 'Income', 'Investment'),
(@root_user_id, @credit_id, @marketing_project_id, DATE_SUB(CURDATE(), INTERVAL 9 DAY), 'Facebook Ads', -450.00, 'Expense', 'Marketing'),
(@root_user_id, @checking_id, NULL, DATE_SUB(CURDATE(), INTERVAL 10 DAY), 'Phone Bill', -75.00, 'Expense', 'Bills & Utilities');

-- Insert sample recurring payments for root user
INSERT INTO payments (user_id, account_id, name, description, amount, frequency, next_date, is_active, category) VALUES
(@root_user_id, @checking_id, 'Rent Payment', 'Monthly apartment rent', 1200.00, 'Monthly', DATE_ADD(CURDATE(), INTERVAL 5 DAY), TRUE, 'Rent/Mortgage'),
(@root_user_id, @checking_id, 'Netflix Subscription', 'Monthly streaming service', 15.99, 'Monthly', DATE_ADD(CURDATE(), INTERVAL 10 DAY), TRUE, 'Subscriptions'),
(@root_user_id, @checking_id, 'Car Insurance', 'Quarterly car insurance premium', 450.00, 'Quarterly', DATE_ADD(CURDATE(), INTERVAL 45 DAY), TRUE, 'Insurance'),
(@root_user_id, @checking_id, 'Gym Membership', 'Monthly gym subscription', 49.99, 'Monthly', DATE_ADD(CURDATE(), INTERVAL 3 DAY), TRUE, 'Health & Fitness'),
(@root_user_id, @business_id, 'Office Rent', 'Monthly office space rental', 2500.00, 'Monthly', DATE_ADD(CURDATE(), INTERVAL 1 DAY), TRUE, 'Rent/Mortgage'),
(@root_user_id, @credit_id, 'Spotify Premium', 'Music streaming service', 9.99, 'Monthly', DATE_ADD(CURDATE(), INTERVAL 15 DAY), TRUE, 'Subscriptions');