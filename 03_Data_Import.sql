-- ============================================================
-- CART-X | 03_Data_Import.sql
-- Purpose: Prepare staging tables and load the nine source CSVs.
-- Database: cartx_ecommerce | MySQL 8.0
--
-- BEFORE RUNNING:
-- 1. Update every CSV path below to the location on YOUR computer.
-- 2. Confirm local_infile is enabled in the MySQL server/client.
-- 3. Confirm the nine STG tables exist and are empty for a fresh load.
-- 4. This script inserts data. Do not rerun it on populated tables
--    unless you intentionally want duplicate rows.
-- 5. This script does not TRUNCATE or DROP any table.
--
-- The original cartx4.sql contained TRUNCATE TABLE stg_products
-- AFTER loading the CSVs. That destructive statement is excluded.
-- Product VARCHAR preparation is already covered in this script's
-- preparation section (from the reviewed cartx3.sql).
-- ============================================================

USE cartx_ecommerce;

-- ------------------------------------------------------------
-- 1. Confirm local import setting
-- ------------------------------------------------------------
SHOW GLOBAL VARIABLES LIKE 'local_infile';

-- If necessary, and if you have permission, enable it separately:
-- SET GLOBAL local_infile = 1;


-- ------------------------------------------------------------
-- 2. Prepare raw staging columns as VARCHAR
-- ------------------------------------------------------------
-- Retain raw imported values as text. Numeric/date conversion and
-- validation are handled later during CORE transformations.

ALTER TABLE stg_order_items
    MODIFY order_item_id VARCHAR(50),
    MODIFY price VARCHAR(50),
    MODIFY freight_value VARCHAR(50);

ALTER TABLE stg_order_payments
    MODIFY payment_sequential VARCHAR(50),
    MODIFY payment_installments VARCHAR(50),
    MODIFY payment_value VARCHAR(50);

ALTER TABLE stg_order_reviews
    MODIFY review_score VARCHAR(50);

ALTER TABLE stg_products
    MODIFY product_name_length VARCHAR(50),
    MODIFY product_description_length VARCHAR(50),
    MODIFY product_photos_qty VARCHAR(50),
    MODIFY product_weight_g VARCHAR(50),
    MODIFY product_length_cm VARCHAR(50),
    MODIFY product_height_cm VARCHAR(50),
    MODIFY product_width_cm VARCHAR(50);

ALTER TABLE stg_geolocation
    MODIFY geolocation_lat VARCHAR(50),
    MODIFY geolocation_lng VARCHAR(50);


-- ------------------------------------------------------------
-- 3. Load customers
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/YOUR_CSV_FOLDER/olist_customers_dataset.csv'
INTO TABLE stg_customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
);
SHOW WARNINGS;


-- ------------------------------------------------------------
-- 3. Load orders
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/YOUR_CSV_FOLDER/olist_orders_dataset.csv'
INTO TABLE stg_orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
);
SHOW WARNINGS;


-- ------------------------------------------------------------
-- 4. Load order items
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/YOUR_CSV_FOLDER/olist_order_items_dataset.csv'
INTO TABLE stg_order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
);
SHOW WARNINGS;


-- ------------------------------------------------------------
-- 5. Load order payments
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/YOUR_CSV_FOLDER/olist_order_payments_dataset.csv'
INTO TABLE stg_order_payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
);
SHOW WARNINGS;


-- ------------------------------------------------------------
-- 6. Load order reviews
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/YOUR_CSV_FOLDER/olist_order_reviews_dataset.csv'
INTO TABLE stg_order_reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
);
SHOW WARNINGS;


-- ------------------------------------------------------------
-- 7. Load products
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/YOUR_CSV_FOLDER/olist_products_dataset.csv'
INTO TABLE stg_products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
);
SHOW WARNINGS;


-- ------------------------------------------------------------
-- 8. Load sellers
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/YOUR_CSV_FOLDER/olist_sellers_dataset.csv'
INTO TABLE stg_sellers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
);
SHOW WARNINGS;


-- ------------------------------------------------------------
-- 9. Load geolocation
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/YOUR_CSV_FOLDER/olist_geolocation_dataset.csv'
INTO TABLE stg_geolocation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
);
SHOW WARNINGS;


-- ------------------------------------------------------------
-- 10. Load category translation
-- ------------------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/YOUR_CSV_FOLDER/product_category_name_translation.csv'
INTO TABLE stg_category_translation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    product_category_name,
    product_category_name_english
);
SHOW WARNINGS;


-- ------------------------------------------------------------
-- 11. Validate staging row counts
-- ------------------------------------------------------------
SELECT 'stg_customers' AS table_name, COUNT(*) AS total_rows FROM stg_customers
UNION ALL
SELECT 'stg_orders', COUNT(*) FROM stg_orders
UNION ALL
SELECT 'stg_order_items', COUNT(*) FROM stg_order_items
UNION ALL
SELECT 'stg_order_payments', COUNT(*) FROM stg_order_payments
UNION ALL
SELECT 'stg_order_reviews', COUNT(*) FROM stg_order_reviews
UNION ALL
SELECT 'stg_products', COUNT(*) FROM stg_products
UNION ALL
SELECT 'stg_sellers', COUNT(*) FROM stg_sellers
UNION ALL
SELECT 'stg_geolocation', COUNT(*) FROM stg_geolocation
UNION ALL
SELECT 'stg_category_translation', COUNT(*) FROM stg_category_translation;


-- ------------------------------------------------------------
-- 12. Check missing business identifiers
-- ------------------------------------------------------------
SELECT
    'stg_customers' AS table_name,
    COUNT(*) AS total_rows,
    SUM(customer_id IS NULL OR customer_id = '') AS missing_ids
FROM stg_customers
UNION ALL
SELECT
    'stg_orders',
    COUNT(*),
    SUM(order_id IS NULL OR order_id = '')
FROM stg_orders
UNION ALL
SELECT
    'stg_products',
    COUNT(*),
    SUM(product_id IS NULL OR product_id = '')
FROM stg_products
UNION ALL
SELECT
    'stg_sellers',
    COUNT(*),
    SUM(seller_id IS NULL OR seller_id = '')
FROM stg_sellers;


-- ------------------------------------------------------------
-- 13. Check uniqueness of entity identifiers
-- ------------------------------------------------------------
-- These checks compare total rows with distinct IDs.
-- A difference indicates repeated identifiers; it does not
-- automatically prove that every repeated row is invalid.

SELECT
    'stg_customers' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS distinct_ids
FROM stg_customers
UNION ALL
SELECT
    'stg_orders',
    COUNT(*),
    COUNT(DISTINCT order_id)
FROM stg_orders
UNION ALL
SELECT
    'stg_products',
    COUNT(*),
    COUNT(DISTINCT product_id)
FROM stg_products
UNION ALL
SELECT
    'stg_sellers',
    COUNT(*),
    COUNT(DISTINCT seller_id)
FROM stg_sellers;

-- End of staging import and initial validation.
