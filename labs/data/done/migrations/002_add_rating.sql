-- 002: products get a customer rating (0.0 to 5.0). Safe to run more than once.
ALTER TABLE products ADD COLUMN IF NOT EXISTS rating NUMERIC(2,1);
UPDATE products SET rating = CASE id
    WHEN 1 THEN 4.3 WHEN 2 THEN 4.6 WHEN 3 THEN 4.1 WHEN 4 THEN 3.9
    WHEN 5 THEN 4.8 WHEN 6 THEN 4.4 WHEN 7 THEN 4.0 WHEN 8 THEN 4.5
    ELSE 4.0 END
WHERE rating IS NULL;
