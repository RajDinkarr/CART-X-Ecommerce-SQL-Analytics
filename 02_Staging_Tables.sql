-- =========================================================
-- PROJECT: CART-X
-- FILE: 02_Staging_Tables.sql
-- PURPOSE: Create the nine raw landing/staging tables.
--
-- DESIGN NOTES:
-- 1. These tables intentionally have no primary or foreign keys.
-- 2. Raw data is first loaded here before cleaning and conversion.
-- 3. The next import-preparation step changes selected columns
--    to VARCHAR so source values can be loaded before conversion.
--
-- IMPORTANT:
-- Run this file only when creating CART-X in a fresh database.
-- It uses CREATE TABLE statements and is not intended to be
-- rerun over tables that already exist.
-- =========================================================

USE cartx_ecommerce;

-- 1. Customers
CREATE TABLE stg_customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(100),
    customer_state VARCHAR(10)
);

-- 2. Orders
CREATE TABLE stg_orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(30),
    order_purchase_timestamp VARCHAR(30),
    order_approved_at VARCHAR(30),
    order_delivered_carrier_date VARCHAR(30),
    order_delivered_customer_date VARCHAR(30),
    order_estimated_delivery_date VARCHAR(30)
);

-- 3. Order Items
CREATE TABLE stg_order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date VARCHAR(30),
    price DECIMAL(12,2),
    freight_value DECIMAL(12,2)
);

-- 4. Order Payments
CREATE TABLE stg_order_payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(30),
    payment_installments INT,
    payment_value DECIMAL(12,2)
);

-- 5. Order Reviews
CREATE TABLE stg_order_reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date VARCHAR(30),
    review_answer_timestamp VARCHAR(30)
);

-- 6. Products
CREATE TABLE stg_products (
    product_id VARCHAR(50),
    product_category_name VARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

-- 7. Sellers
CREATE TABLE stg_sellers (
    seller_id VARCHAR(50),
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(100),
    seller_state VARCHAR(10)
);

-- 8. Geolocation
CREATE TABLE stg_geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat DECIMAL(10,7),
    geolocation_lng DECIMAL(10,7),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(10)
);

-- 9. Category Translation
CREATE TABLE stg_category_translation (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100)
);

-- Basic structure check.
SHOW TABLES;
