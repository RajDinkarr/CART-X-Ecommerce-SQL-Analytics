/*
===============================================================================
CART-X | 07_Final_Validation.sql
Purpose : Final structural, row-count, key and data-integrity audit.
Database: cartx_ecommerce
Engine  : MySQL 8.0+

EXECUTION
1. Run after the setup, import, CORE, MART and business-analysis scripts.
2. This script is READ-ONLY. It does not create, alter, update, delete,
   truncate or drop any table.
3. Run each section and inspect the result. Some checks intentionally return
   zero rows when no violations are found.
4. Expected row counts are checkpoints for this specific source dataset.

IMPORTANT
- Exact COUNT(*) values are used; information_schema.TABLE_ROWS can be an
  estimate for InnoDB tables.
- Staging tables intentionally have no primary keys.
- core_geolocation_backup is a retained copy of the original geolocation data.
- MART tables are analytical summaries, not replacements for CORE tables.
===============================================================================
*/

USE cartx_ecommerce;

-- ============================================================================
-- 1. DATABASE INVENTORY
-- Confirm the expected layers and table counts.
-- ============================================================================

SELECT
    CASE
        WHEN table_name LIKE 'stg\\_%' THEN 'STG'
        WHEN table_name LIKE 'core\\_%' THEN 'CORE'
        WHEN table_name LIKE 'mart\\_%' THEN 'MART'
        ELSE 'OTHER'
    END AS data_layer,
    COUNT(*) AS table_count
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_type = 'BASE TABLE'
GROUP BY data_layer
ORDER BY data_layer;

-- Full table inventory with exact row counts.
SELECT 'stg_customers' AS table_name, COUNT(*) AS exact_rows FROM stg_customers
UNION ALL SELECT 'stg_orders', COUNT(*) FROM stg_orders
UNION ALL SELECT 'stg_order_items', COUNT(*) FROM stg_order_items
UNION ALL SELECT 'stg_order_payments', COUNT(*) FROM stg_order_payments
UNION ALL SELECT 'stg_order_reviews', COUNT(*) FROM stg_order_reviews
UNION ALL SELECT 'stg_products', COUNT(*) FROM stg_products
UNION ALL SELECT 'stg_sellers', COUNT(*) FROM stg_sellers
UNION ALL SELECT 'stg_geolocation', COUNT(*) FROM stg_geolocation
UNION ALL SELECT 'stg_category_translation', COUNT(*) FROM stg_category_translation
UNION ALL SELECT 'core_customers', COUNT(*) FROM core_customers
UNION ALL SELECT 'core_orders', COUNT(*) FROM core_orders
UNION ALL SELECT 'core_sellers', COUNT(*) FROM core_sellers
UNION ALL SELECT 'core_products', COUNT(*) FROM core_products
UNION ALL SELECT 'core_order_items', COUNT(*) FROM core_order_items
UNION ALL SELECT 'core_order_payments', COUNT(*) FROM core_order_payments
UNION ALL SELECT 'core_order_reviews', COUNT(*) FROM core_order_reviews
UNION ALL SELECT 'core_geolocation', COUNT(*) FROM core_geolocation
UNION ALL SELECT 'core_geolocation_backup', COUNT(*) FROM core_geolocation_backup
UNION ALL SELECT 'core_category_translation', COUNT(*) FROM core_category_translation
UNION ALL SELECT 'mart_sales_performance', COUNT(*) FROM mart_sales_performance
UNION ALL SELECT 'mart_customer_performance', COUNT(*) FROM mart_customer_performance
UNION ALL SELECT 'mart_product_performance', COUNT(*) FROM mart_product_performance
UNION ALL SELECT 'mart_seller_performance', COUNT(*) FROM mart_seller_performance
UNION ALL SELECT 'mart_delivery_performance', COUNT(*) FROM mart_delivery_performance
UNION ALL SELECT 'mart_payment_performance', COUNT(*) FROM mart_payment_performance
ORDER BY table_name;

-- Expected row-count checkpoints for this project's completed dataset.
-- Any mismatch should be investigated; do not blindly force a count to match.
SELECT
    expected.table_name,
    expected.expected_rows,
    actual.actual_rows,
    CASE
        WHEN actual.actual_rows = expected.expected_rows THEN 'PASS'
        ELSE 'CHECK'
    END AS validation_status
FROM (
    SELECT 'stg_customers' AS table_name, 99441 AS expected_rows
    UNION ALL SELECT 'stg_orders', 99441
    UNION ALL SELECT 'stg_order_items', 112650
    UNION ALL SELECT 'stg_order_payments', 103886
    UNION ALL SELECT 'stg_order_reviews', 99224
    UNION ALL SELECT 'stg_products', 32951
    UNION ALL SELECT 'stg_sellers', 3095
    UNION ALL SELECT 'stg_geolocation', 1000163
    UNION ALL SELECT 'stg_category_translation', 71
    UNION ALL SELECT 'core_customers', 99441
    UNION ALL SELECT 'core_orders', 99441
    UNION ALL SELECT 'core_sellers', 3095
    UNION ALL SELECT 'core_products', 32951
    UNION ALL SELECT 'core_order_items', 112650
    UNION ALL SELECT 'core_order_payments', 103886
    UNION ALL SELECT 'core_order_reviews', 99224
    UNION ALL SELECT 'core_geolocation', 720496
    UNION ALL SELECT 'core_geolocation_backup', 1000163
    UNION ALL SELECT 'core_category_translation', 71
    UNION ALL SELECT 'mart_sales_performance', 25
    UNION ALL SELECT 'mart_customer_performance', 93358
    UNION ALL SELECT 'mart_product_performance', 74
    UNION ALL SELECT 'mart_seller_performance', 2970
    UNION ALL SELECT 'mart_delivery_performance', 556
    UNION ALL SELECT 'mart_payment_performance', 28
) AS expected
JOIN (
    SELECT 'stg_customers' AS table_name, COUNT(*) AS actual_rows FROM stg_customers
    UNION ALL SELECT 'stg_orders', COUNT(*) FROM stg_orders
    UNION ALL SELECT 'stg_order_items', COUNT(*) FROM stg_order_items
    UNION ALL SELECT 'stg_order_payments', COUNT(*) FROM stg_order_payments
    UNION ALL SELECT 'stg_order_reviews', COUNT(*) FROM stg_order_reviews
    UNION ALL SELECT 'stg_products', COUNT(*) FROM stg_products
    UNION ALL SELECT 'stg_sellers', COUNT(*) FROM stg_sellers
    UNION ALL SELECT 'stg_geolocation', COUNT(*) FROM stg_geolocation
    UNION ALL SELECT 'stg_category_translation', COUNT(*) FROM stg_category_translation
    UNION ALL SELECT 'core_customers', COUNT(*) FROM core_customers
    UNION ALL SELECT 'core_orders', COUNT(*) FROM core_orders
    UNION ALL SELECT 'core_sellers', COUNT(*) FROM core_sellers
    UNION ALL SELECT 'core_products', COUNT(*) FROM core_products
    UNION ALL SELECT 'core_order_items', COUNT(*) FROM core_order_items
    UNION ALL SELECT 'core_order_payments', COUNT(*) FROM core_order_payments
    UNION ALL SELECT 'core_order_reviews', COUNT(*) FROM core_order_reviews
    UNION ALL SELECT 'core_geolocation', COUNT(*) FROM core_geolocation
    UNION ALL SELECT 'core_geolocation_backup', COUNT(*) FROM core_geolocation_backup
    UNION ALL SELECT 'core_category_translation', COUNT(*) FROM core_category_translation
    UNION ALL SELECT 'mart_sales_performance', COUNT(*) FROM mart_sales_performance
    UNION ALL SELECT 'mart_customer_performance', COUNT(*) FROM mart_customer_performance
    UNION ALL SELECT 'mart_product_performance', COUNT(*) FROM mart_product_performance
    UNION ALL SELECT 'mart_seller_performance', COUNT(*) FROM mart_seller_performance
    UNION ALL SELECT 'mart_delivery_performance', COUNT(*) FROM mart_delivery_performance
    UNION ALL SELECT 'mart_payment_performance', COUNT(*) FROM mart_payment_performance
) AS actual
    ON expected.table_name = actual.table_name
ORDER BY expected.table_name;

-- ============================================================================
-- 2. PRIMARY KEY AUDIT
-- Staging tables are intentionally excluded because raw staging preserves
-- source rows without imposing analytical keys.
-- ============================================================================

-- List every primary key currently defined in CORE and MART.
SELECT
    tc.table_name,
    GROUP_CONCAT(
        kcu.column_name
        ORDER BY kcu.ordinal_position
        SEPARATOR ', '
    ) AS primary_key_columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_schema = kcu.constraint_schema
   AND tc.table_name = kcu.table_name
   AND tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_schema = DATABASE()
  AND tc.constraint_type = 'PRIMARY KEY'
  AND (tc.table_name LIKE 'core\\_%'
       OR tc.table_name LIKE 'mart\\_%')
GROUP BY tc.table_name
ORDER BY tc.table_name;

-- Expected CORE/MART tables missing a primary key.
SELECT expected.table_name
FROM (
    SELECT 'core_customers' AS table_name
    UNION ALL SELECT 'core_orders'
    UNION ALL SELECT 'core_sellers'
    UNION ALL SELECT 'core_products'
    UNION ALL SELECT 'core_order_items'
    UNION ALL SELECT 'core_order_payments'
    UNION ALL SELECT 'core_order_reviews'
    UNION ALL SELECT 'core_geolocation'
    UNION ALL SELECT 'core_category_translation'
    UNION ALL SELECT 'mart_sales_performance'
    UNION ALL SELECT 'mart_customer_performance'
    UNION ALL SELECT 'mart_product_performance'
    UNION ALL SELECT 'mart_seller_performance'
    UNION ALL SELECT 'mart_delivery_performance'
    UNION ALL SELECT 'mart_payment_performance'
) expected
LEFT JOIN information_schema.table_constraints tc
    ON tc.constraint_schema = DATABASE()
   AND tc.table_name = expected.table_name
   AND tc.constraint_type = 'PRIMARY KEY'
WHERE tc.constraint_name IS NULL
ORDER BY expected.table_name;

-- Confirm the geolocation surrogate key is populated and unique.
SELECT
    COUNT(*) AS total_rows,
    COUNT(geo_row_id) AS non_null_geo_ids,
    COUNT(DISTINCT geo_row_id) AS distinct_geo_ids,
    MIN(geo_row_id) AS minimum_geo_id,
    MAX(geo_row_id) AS maximum_geo_id
FROM core_geolocation;

-- ============================================================================
-- 3. FOREIGN KEY AUDIT
-- Expected relationships:
-- orders -> customers
-- order_items -> orders, products, sellers
-- payments -> orders
-- reviews -> orders
-- ============================================================================

-- List the foreign keys actually defined in the database.
SELECT
    table_name,
    column_name,
    constraint_name,
    referenced_table_name,
    referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = DATABASE()
  AND referenced_table_name IS NOT NULL
ORDER BY table_name, constraint_name, ordinal_position;

-- Expected foreign-key relationships that are missing.
SELECT
    expected.child_table,
    expected.child_column,
    expected.parent_table,
    expected.parent_column
FROM (
    SELECT 'core_orders' AS child_table, 'customer_id' AS child_column,
           'core_customers' AS parent_table, 'customer_id' AS parent_column
    UNION ALL SELECT 'core_order_items', 'order_id', 'core_orders', 'order_id'
    UNION ALL SELECT 'core_order_items', 'product_id', 'core_products', 'product_id'
    UNION ALL SELECT 'core_order_items', 'seller_id', 'core_sellers', 'seller_id'
    UNION ALL SELECT 'core_order_payments', 'order_id', 'core_orders', 'order_id'
    UNION ALL SELECT 'core_order_reviews', 'order_id', 'core_orders', 'order_id'
) expected
LEFT JOIN information_schema.key_column_usage actual
    ON actual.table_schema = DATABASE()
   AND actual.table_name = expected.child_table
   AND actual.column_name = expected.child_column
   AND actual.referenced_table_name = expected.parent_table
   AND actual.referenced_column_name = expected.parent_column
WHERE actual.constraint_name IS NULL
ORDER BY expected.child_table, expected.child_column;

-- ============================================================================
-- 4. REFERENTIAL-INTEGRITY CHECKS
-- Each query should return zero rows when no orphan records are present.
-- ============================================================================

-- Orders referencing missing customers.
SELECT o.order_id, o.customer_id
FROM core_orders o
LEFT JOIN core_customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Order items referencing missing orders.
SELECT oi.order_id, oi.order_item_id
FROM core_order_items oi
LEFT JOIN core_orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Order items referencing missing products.
SELECT oi.order_id, oi.order_item_id, oi.product_id
FROM core_order_items oi
LEFT JOIN core_products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Order items referencing missing sellers.
SELECT oi.order_id, oi.order_item_id, oi.seller_id
FROM core_order_items oi
LEFT JOIN core_sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- Payments referencing missing orders.
SELECT p.payment_id, p.order_id
FROM core_order_payments p
LEFT JOIN core_orders o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Reviews referencing missing orders.
SELECT r.review_row_id, r.order_id
FROM core_order_reviews r
LEFT JOIN core_orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- ============================================================================
-- 5. CORE KEY AND DATA-QUALITY CHECKS
-- These summaries provide a final snapshot of known source-data issues.
-- ============================================================================

-- Unique-key checks and known order timestamp flags.
SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_id) AS distinct_order_ids,
    SUM(order_purchase_timestamp IS NULL) AS missing_purchase_dates,
    SUM(order_approved_at IS NULL) AS missing_approval_dates,
    SUM(order_delivered_carrier_date IS NULL) AS missing_carrier_dates,
    SUM(order_delivered_customer_date IS NULL) AS missing_customer_delivery_dates,
    SUM(chronology_anomaly_flag = 1) AS chronology_anomaly_rows
FROM core_orders;

-- Product category and weight checks.
SELECT
    COUNT(*) AS total_products,
    SUM(product_category_name = 'Unknown') AS unknown_categories,
    SUM(product_weight_g IS NULL) AS missing_weights,
    SUM(invalid_weight_flag = 1) AS invalid_weight_flags
FROM core_products;

-- Review source IDs can repeat; review_row_id is the internal row key.
SELECT
    COUNT(*) AS review_rows,
    COUNT(DISTINCT review_row_id) AS distinct_internal_ids,
    COUNT(DISTINCT review_id) AS distinct_source_review_ids,
    COUNT(*) - COUNT(DISTINCT review_id) AS repeated_source_id_occurrences,
    SUM(review_score IS NULL) AS missing_review_scores
FROM core_order_reviews;

-- Exact duplicate groups in the deduplicated geolocation table.
-- This should return zero rows.
SELECT
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state,
    COUNT(*) AS duplicate_count
FROM core_geolocation
GROUP BY
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
HAVING COUNT(*) > 1;

-- Coordinate validity: latitude must be -90..90, longitude -180..180.
SELECT
    COUNT(*) AS total_rows,
    SUM(geolocation_lat IS NULL) AS missing_latitudes,
    SUM(geolocation_lng IS NULL) AS missing_longitudes,
    SUM(geolocation_lat < -90 OR geolocation_lat > 90) AS invalid_latitudes,
    SUM(geolocation_lng < -180 OR geolocation_lng > 180) AS invalid_longitudes
FROM core_geolocation;

-- ============================================================================
-- 6. MART RECONCILIATION
-- Reconcile summary totals back to CORE at matching grains.
-- ============================================================================

-- Delivered order/item/product-value reconciliation.
SELECT
    (SELECT COUNT(*)
     FROM core_orders
     WHERE order_status = 'delivered') AS core_delivered_orders,
    (SELECT SUM(delivered_orders)
     FROM mart_sales_performance) AS mart_delivered_orders,
    (SELECT COUNT(*)
     FROM core_order_items oi
     JOIN core_orders o ON oi.order_id = o.order_id
     WHERE o.order_status = 'delivered') AS core_delivered_item_rows,
    (SELECT SUM(total_items_sold)
     FROM mart_sales_performance) AS mart_delivered_item_rows,
    (SELECT ROUND(SUM(oi.price), 2)
     FROM core_order_items oi
     JOIN core_orders o ON oi.order_id = o.order_id
     WHERE o.order_status = 'delivered') AS core_delivered_product_revenue,
    (SELECT ROUND(SUM(product_revenue), 2)
     FROM mart_sales_performance) AS mart_delivered_product_revenue;

-- Payment-record and payment-value reconciliation.
SELECT
    (SELECT COUNT(*) FROM core_order_payments) AS core_payment_records,
    (SELECT SUM(total_payment_records)
     FROM mart_payment_performance) AS mart_payment_records,
    (SELECT ROUND(SUM(payment_value), 2)
     FROM core_order_payments) AS core_payment_value,
    (SELECT ROUND(SUM(total_payment_value), 2)
     FROM mart_payment_performance) AS mart_payment_value;

-- Delivery cohort reconciliation.
-- The MART includes delivered orders with purchase, actual-delivery and
-- estimated-delivery timestamps, grouped by purchase month and customer state.
SELECT
    (SELECT COUNT(*)
     FROM core_orders
     WHERE order_status = 'delivered'
       AND order_purchase_timestamp IS NOT NULL
       AND order_delivered_customer_date IS NOT NULL
       AND order_estimated_delivery_date IS NOT NULL) AS eligible_core_orders,
    (SELECT SUM(total_delivered_orders)
     FROM mart_delivery_performance) AS mart_eligible_orders,
    (SELECT SUM(late_orders)
     FROM mart_delivery_performance) AS mart_late_orders,
    (SELECT SUM(on_time_orders)
     FROM mart_delivery_performance) AS mart_on_time_or_early_orders;

-- ============================================================================
-- 7. MART GRAIN DUPLICATE CHECKS
-- Each query should return zero rows. Primary keys also enforce these grains.
-- ============================================================================

SELECT month_start, COUNT(*) AS duplicate_rows
FROM mart_sales_performance
GROUP BY month_start
HAVING COUNT(*) > 1;

SELECT customer_unique_id, COUNT(*) AS duplicate_rows
FROM mart_customer_performance
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

SELECT product_category, COUNT(*) AS duplicate_rows
FROM mart_product_performance
GROUP BY product_category
HAVING COUNT(*) > 1;

SELECT seller_id, COUNT(*) AS duplicate_rows
FROM mart_seller_performance
GROUP BY seller_id
HAVING COUNT(*) > 1;

SELECT month_start, customer_state, COUNT(*) AS duplicate_rows
FROM mart_delivery_performance
GROUP BY month_start, customer_state
HAVING COUNT(*) > 1;

SELECT payment_type, payment_installments, COUNT(*) AS duplicate_rows
FROM mart_payment_performance
GROUP BY payment_type, payment_installments
HAVING COUNT(*) > 1;

/*
===============================================================================
END OF FINAL VALIDATION

Interpretation:
- Expected row-count table: all rows should show PASS for the documented data.
- Missing-PK and missing-FK queries: zero rows means all expected constraints
  are present.
- Orphan and duplicate queries: zero rows means no violations were detected.
- Reconciliation queries: CORE and MART totals should agree where the grain
  and population definitions match.
- A non-zero result is a prompt to investigate, not permission to edit counts
  or remove records without understanding the cause.
===============================================================================
*/
