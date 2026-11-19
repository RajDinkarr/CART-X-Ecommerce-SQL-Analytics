-- ============================================================
-- CART-X | 04_Core_Transformations.sql
-- Purpose: Build the cleaned CORE layer from the STG layer.
-- Database: cartx_ecommerce | MySQL 8.0
--
-- IMPORTANT:
-- - This is a rebuild script for a FRESH/EMPTY project database.
-- - It creates tables and inserts data; it is not a safe rerun script.
-- - Do not execute against your existing completed CORE layer.
-- - Keep the original cartx6.sql in DEVELOPMENT_HISTORY unchanged.
-- - Run only after all nine STG tables have been imported and checked.
--
-- Design:
-- STG = raw source values
-- CORE = typed, cleaned, keyed relational tables
-- ============================================================

USE cartx_ecommerce;


-- ============================================================
-- 1. CORE CUSTOMERS
-- ============================================================

CREATE TABLE core_customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(100),
    customer_state VARCHAR(10)
);

INSERT INTO core_customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT
    NULLIF(TRIM(customer_id), ''),
    NULLIF(TRIM(customer_unique_id), ''),
    NULLIF(TRIM(customer_zip_code_prefix), ''),
    NULLIF(TRIM(customer_city), ''),
    NULLIF(TRIM(customer_state), '')
FROM stg_customers;


-- ============================================================
-- 2. CORE ORDERS
-- Convert text dates to DATETIME and retain quality flags.
-- ============================================================

CREATE TABLE core_orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(30),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME,
    approval_missing_flag TINYINT DEFAULT 0,
    carrier_missing_flag TINYINT DEFAULT 0,
    delivery_missing_flag TINYINT DEFAULT 0,
    chronology_anomaly_flag TINYINT DEFAULT 0,
    CONSTRAINT fk_core_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES core_customers(customer_id)
);

INSERT INTO core_orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    approval_missing_flag,
    carrier_missing_flag,
    delivery_missing_flag,
    chronology_anomaly_flag
)
SELECT
    order_id,
    customer_id,
    order_status,
    purchase_date,
    approval_date,
    carrier_date,
    delivery_date,
    estimated_date,
    CASE WHEN approval_date IS NULL THEN 1 ELSE 0 END,
    CASE WHEN carrier_date IS NULL THEN 1 ELSE 0 END,
    CASE WHEN delivery_date IS NULL THEN 1 ELSE 0 END,
    CASE
        WHEN (approval_date IS NOT NULL AND approval_date < purchase_date)
          OR (carrier_date IS NOT NULL AND carrier_date < purchase_date)
          OR (carrier_date IS NOT NULL AND approval_date IS NOT NULL
              AND carrier_date < approval_date)
          OR (delivery_date IS NOT NULL AND carrier_date IS NOT NULL
              AND delivery_date < carrier_date)
        THEN 1 ELSE 0
    END
FROM (
    SELECT
        order_id,
        customer_id,
        order_status,
        STR_TO_DATE(NULLIF(TRIM(order_purchase_timestamp), ''),
                    '%Y-%m-%d %H:%i:%s') AS purchase_date,
        STR_TO_DATE(NULLIF(TRIM(order_approved_at), ''),
                    '%Y-%m-%d %H:%i:%s') AS approval_date,
        STR_TO_DATE(NULLIF(TRIM(order_delivered_carrier_date), ''),
                    '%Y-%m-%d %H:%i:%s') AS carrier_date,
        STR_TO_DATE(NULLIF(TRIM(order_delivered_customer_date), ''),
                    '%Y-%m-%d %H:%i:%s') AS delivery_date,
        STR_TO_DATE(NULLIF(TRIM(order_estimated_delivery_date), ''),
                    '%Y-%m-%d %H:%i:%s') AS estimated_date
    FROM stg_orders
) AS cleaned_orders;


-- ============================================================
-- 3. CORE SELLERS
-- ============================================================

CREATE TABLE core_sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(100),
    seller_state VARCHAR(10)
);

INSERT INTO core_sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT
    NULLIF(TRIM(seller_id), ''),
    NULLIF(TRIM(seller_zip_code_prefix), ''),
    NULLIF(TRIM(seller_city), ''),
    NULLIF(TRIM(seller_state), '')
FROM stg_sellers;


-- ============================================================
-- 4. CORE PRODUCTS
-- Blank categories become 'Unknown'.
-- Non-positive weights are set to NULL and flagged.
-- ============================================================

CREATE TABLE core_products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g DECIMAL(12,2),
    product_length_cm DECIMAL(12,2),
    product_height_cm DECIMAL(12,2),
    product_width_cm DECIMAL(12,2),
    invalid_weight_flag TINYINT DEFAULT 0
);

INSERT INTO core_products (
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    invalid_weight_flag
)
SELECT
    product_id,
    COALESCE(NULLIF(TRIM(product_category_name), ''), 'Unknown'),
    CAST(NULLIF(TRIM(product_name_length), '') AS UNSIGNED),
    CAST(NULLIF(TRIM(product_description_length), '') AS UNSIGNED),
    CAST(NULLIF(TRIM(product_photos_qty), '') AS UNSIGNED),
    CASE
        WHEN CAST(NULLIF(TRIM(product_weight_g), '') AS DECIMAL(12,2)) <= 0
            THEN NULL
        ELSE CAST(NULLIF(TRIM(product_weight_g), '') AS DECIMAL(12,2))
    END,
    CAST(NULLIF(TRIM(product_length_cm), '') AS DECIMAL(12,2)),
    CAST(NULLIF(TRIM(product_height_cm), '') AS DECIMAL(12,2)),
    CAST(NULLIF(TRIM(product_width_cm), '') AS DECIMAL(12,2)),
    CASE
        WHEN CAST(NULLIF(TRIM(product_weight_g), '') AS DECIMAL(12,2)) <= 0
            THEN 1
        ELSE 0
    END
FROM stg_products;


-- ============================================================
-- 5. CORE ORDER ITEMS
-- Composite primary key: order_id + order_item_id.
-- ============================================================

CREATE TABLE core_order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(12,2),
    freight_value DECIMAL(12,2),
    PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_core_items_order
        FOREIGN KEY (order_id) REFERENCES core_orders(order_id),
    CONSTRAINT fk_core_items_product
        FOREIGN KEY (product_id) REFERENCES core_products(product_id),
    CONSTRAINT fk_core_items_seller
        FOREIGN KEY (seller_id) REFERENCES core_sellers(seller_id)
);

INSERT INTO core_order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
)
SELECT
    order_id,
    CAST(NULLIF(TRIM(order_item_id), '') AS UNSIGNED),
    product_id,
    seller_id,
    STR_TO_DATE(NULLIF(TRIM(shipping_limit_date), ''),
                '%Y-%m-%d %H:%i:%s'),
    CAST(NULLIF(TRIM(price), '') AS DECIMAL(12,2)),
    CAST(NULLIF(TRIM(freight_value), '') AS DECIMAL(12,2))
FROM stg_order_items;


-- ============================================================
-- 6. CORE ORDER PAYMENTS
-- Internal payment_id is generated because source rows are
-- identified by the combination of order_id + payment_sequential.
-- ============================================================

CREATE TABLE core_order_payments (
    payment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(30),
    payment_installments INT,
    payment_value DECIMAL(12,2),
    zero_payment_flag TINYINT DEFAULT 0,
    UNIQUE KEY uq_core_payment_order_sequence
        (order_id, payment_sequential),
    CONSTRAINT fk_core_payments_order
        FOREIGN KEY (order_id) REFERENCES core_orders(order_id)
);

INSERT INTO core_order_payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value,
    zero_payment_flag
)
SELECT
    order_id,
    CAST(NULLIF(TRIM(payment_sequential), '') AS UNSIGNED),
    NULLIF(TRIM(payment_type), ''),
    CAST(NULLIF(TRIM(payment_installments), '') AS UNSIGNED),
    CAST(NULLIF(TRIM(payment_value), '') AS DECIMAL(12,2)),
    CASE
        WHEN CAST(NULLIF(TRIM(payment_value), '') AS DECIMAL(12,2)) = 0
            THEN 1
        ELSE 0
    END
FROM stg_order_payments;


-- ============================================================
-- 7. CORE ORDER REVIEWS
-- Keep repeated source review_id values; review_row_id is the
-- unique internal primary key for each source row.
-- ============================================================

CREATE TABLE core_order_reviews (
    review_row_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME,
    CONSTRAINT fk_core_reviews_order
        FOREIGN KEY (order_id) REFERENCES core_orders(order_id)
);

INSERT INTO core_order_reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
SELECT
    review_id,
    order_id,
    CAST(NULLIF(TRIM(review_score), '') AS UNSIGNED),
    NULLIF(TRIM(review_comment_title), ''),
    NULLIF(TRIM(review_comment_message), ''),
    STR_TO_DATE(NULLIF(TRIM(review_creation_date), ''),
                '%Y-%m-%d %H:%i:%s'),
    STR_TO_DATE(NULLIF(TRIM(review_answer_timestamp), ''),
                '%Y-%m-%d %H:%i:%s')
FROM stg_order_reviews;


-- ============================================================
-- 8. CORE GEOLOCATION
-- Preserve the complete source-derived dataset in a backup table.
-- Active table contains exact distinct combinations only.
-- Coordinates use DECIMAL(25,20), and geo_row_id is the PK.
-- ============================================================

CREATE TABLE core_geolocation_backup (
    geo_row_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat DECIMAL(25,20),
    geolocation_lng DECIMAL(25,20),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(10)
);

INSERT INTO core_geolocation_backup (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)
SELECT
    NULLIF(TRIM(geolocation_zip_code_prefix), ''),
    CAST(NULLIF(TRIM(geolocation_lat), '') AS DECIMAL(25,20)),
    CAST(NULLIF(TRIM(geolocation_lng), '') AS DECIMAL(25,20)),
    NULLIF(TRIM(geolocation_city), ''),
    NULLIF(TRIM(geolocation_state), '')
FROM stg_geolocation;

CREATE TABLE core_geolocation (
    geo_row_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat DECIMAL(25,20),
    geolocation_lng DECIMAL(25,20),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(10)
);

INSERT INTO core_geolocation (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)
SELECT DISTINCT
    NULLIF(TRIM(geolocation_zip_code_prefix), ''),
    CAST(NULLIF(TRIM(geolocation_lat), '') AS DECIMAL(25,20)),
    CAST(NULLIF(TRIM(geolocation_lng), '') AS DECIMAL(25,20)),
    NULLIF(TRIM(geolocation_city), ''),
    NULLIF(TRIM(geolocation_state), '')
FROM stg_geolocation;


-- ============================================================
-- 9. CORE CATEGORY TRANSLATION
-- ============================================================

CREATE TABLE core_category_translation (
    product_category_name VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100)
);

INSERT INTO core_category_translation (
    product_category_name,
    product_category_name_english
)
SELECT
    NULLIF(TRIM(product_category_name), ''),
    NULLIF(TRIM(product_category_name_english), '')
FROM stg_category_translation;


-- ============================================================
-- 10. INITIAL CORE ROW-COUNT VALIDATION
-- Exact COUNT(*) is used instead of information_schema estimates.
-- ============================================================

SELECT 'core_customers' AS table_name, COUNT(*) AS total_rows FROM core_customers
UNION ALL
SELECT 'core_orders', COUNT(*) FROM core_orders
UNION ALL
SELECT 'core_sellers', COUNT(*) FROM core_sellers
UNION ALL
SELECT 'core_products', COUNT(*) FROM core_products
UNION ALL
SELECT 'core_order_items', COUNT(*) FROM core_order_items
UNION ALL
SELECT 'core_order_payments', COUNT(*) FROM core_order_payments
UNION ALL
SELECT 'core_order_reviews', COUNT(*) FROM core_order_reviews
UNION ALL
SELECT 'core_geolocation', COUNT(*) FROM core_geolocation
UNION ALL
SELECT 'core_category_translation', COUNT(*) FROM core_category_translation
UNION ALL
SELECT 'core_geolocation_backup', COUNT(*) FROM core_geolocation_backup;


-- ============================================================
-- 11. INITIAL CORE QUALITY SUMMARY
-- ============================================================

SELECT
    COUNT(*) AS total_orders,
    SUM(order_purchase_timestamp IS NULL) AS missing_purchase_dates,
    SUM(approval_missing_flag) AS missing_approval_dates,
    SUM(carrier_missing_flag) AS missing_carrier_dates,
    SUM(delivery_missing_flag) AS missing_delivery_dates,
    SUM(chronology_anomaly_flag) AS chronology_anomalies
FROM core_orders;

SELECT
    COUNT(*) AS total_products,
    SUM(product_category_name = 'Unknown') AS unknown_categories,
    SUM(product_weight_g IS NULL) AS missing_or_invalid_weights,
    SUM(invalid_weight_flag) AS invalid_weight_records
FROM core_products;

SELECT
    COUNT(*) AS total_reviews,
    COUNT(DISTINCT review_row_id) AS unique_review_rows,
    COUNT(DISTINCT review_id) AS distinct_source_review_ids,
    SUM(review_score IS NULL OR review_score NOT BETWEEN 1 AND 5) AS invalid_scores
FROM core_order_reviews;

SELECT
    COUNT(*) AS total_geolocation_rows,
    COUNT(DISTINCT geo_row_id) AS unique_geo_row_ids,
    MIN(geolocation_lat) AS min_latitude,
    MAX(geolocation_lat) AS max_latitude,
    MIN(geolocation_lng) AS min_longitude,
    MAX(geolocation_lng) AS max_longitude
FROM core_geolocation;

-- End of CORE build.
-- Run the separate final validation script after this build.
