-- A manually selected reporting zone survives device-token and foreground updates.
ALTER TABLE user_momentum ADD COLUMN preferred_timezone_name VARCHAR(64) NULL;
ALTER TABLE user_momentum ADD COLUMN preferred_timezone_offset_min INT NULL;
