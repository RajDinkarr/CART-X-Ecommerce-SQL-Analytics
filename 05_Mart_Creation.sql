/*
===============================================================================
CART-X | 05_Mart_Creation.sql
Purpose : Build six business-ready MART tables from the validated CORE layer.
Database: cartx_ecommerce
Engine  : MySQL 8.0+

IMPORTANT
1. Run only after 04_Core_Transformations.sql has completed successfully.
2. Run against a fresh project database where these six MART tables do not exist.
3. This script does not DROP or TRUNCATE tables. It is not a rerunnable refresh
   script. Do not run it on your already-populated working database.
4. Product revenue is item price only; it excludes freight and is not profit.
5. Payment totals are payment-record values, not automatically recognized sales.
===============================================================================
*/

USE cartx_ecommerce;

-- ============================================================================
-- 1. MONTHLY SALES PERFORMANCE
-- Grain: one row per purchase month.
-- ============================================================================
CREATE TABLE mart_sales_performance (
    month_start DATE PRIMARY KEY,
    total_orders INT,
    delivered_orders INT,
    canceled_orders INT,
    total_items_sold INT,
    product_revenue DECIMAL(15,2),
    total_freight DECIMAL(15,2),
    average_order_value DECIMAL(15,2)
);

INSERT INTO mart_sales_performance (
    month_start,
    total_orders,
    delivered_orders,
    canceled_orders,
    total_items_sold,
    product_revenue,
    total_freight,
    average_order_value
)
WITH monthly_orders AS (
    SELECT
        DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01') AS month_start,
        COUNT(*) AS total_orders,
        SUM(order_status = 'delivered') AS delivered_orders,
        SUM(order_status = 'canceled') AS canceled_orders
    FROM core_orders
    WHERE order_purchase_timestamp IS NOT NULL
    GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01')
),
monthly_items AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS month_start,
        COUNT(*) AS total_items_sold,
        SUM(oi.price) AS product_revenue,
        SUM(oi.freight_value) AS total_freight
    FROM core_orders o
    JOIN core_order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01')
)
SELECT
    mo.month_start,
    mo.total_orders,
    mo.delivered_orders,
    mo.canceled_orders,
    COALESCE(mi.total_items_sold, 0),
    COALESCE(mi.product_revenue, 0),
    COALESCE(mi.total_freight, 0),
    ROUND(
        COALESCE(mi.product_revenue, 0) /
        NULLIF(mo.delivered_orders, 0),
        2
    )
FROM monthly_orders mo
LEFT JOIN monthly_items mi
    ON mo.month_start = mi.month_start;


-- ============================================================================
-- 2. CUSTOMER PERFORMANCE
-- Grain: one row per customer_unique_id, among customers with delivered sales.
-- Spending is based on delivered item prices, not freight.
-- ============================================================================
CREATE TABLE mart_customer_performance (
    customer_unique_id VARCHAR(50) PRIMARY KEY,
    total_orders INT,
    total_product_spending DECIMAL(15,2),
    average_order_value DECIMAL(15,2),
    first_purchase_date DATETIME,
    last_purchase_date DATETIME,
    repeat_customer_flag TINYINT
);

INSERT INTO mart_customer_performance (
    customer_unique_id,
    total_orders,
    total_product_spending,
    average_order_value,
    first_purchase_date,
    last_purchase_date,
    repeat_customer_flag
)
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        MIN(o.order_purchase_timestamp) AS first_purchase_date,
        MAX(o.order_purchase_timestamp) AS last_purchase_date
    FROM core_customers c
    JOIN core_orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_spending AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price) AS total_product_spending
    FROM core_customers c
    JOIN core_orders o
        ON c.customer_id = o.customer_id
    JOIN core_order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    co.customer_unique_id,
    co.total_orders,
    cs.total_product_spending,
    ROUND(cs.total_product_spending / NULLIF(co.total_orders, 0), 2),
    co.first_purchase_date,
    co.last_purchase_date,
    CASE WHEN co.total_orders > 1 THEN 1 ELSE 0 END
FROM customer_orders co
JOIN customer_spending cs
    ON co.customer_unique_id = cs.customer_unique_id;


-- ============================================================================
-- 3. PRODUCT CATEGORY PERFORMANCE
-- Grain: one row per product category among delivered orders.
-- Review score is averaged at order level, then across distinct order-category
-- associations. This avoids multiplying review rows by repeated item rows.
-- ============================================================================
CREATE TABLE mart_product_performance (
    product_category VARCHAR(100) PRIMARY KEY,
    total_products INT,
    total_items_sold INT,
    total_orders INT,
    product_revenue DECIMAL(15,2),
    total_freight DECIMAL(15,2),
    average_item_price DECIMAL(15,2),
    average_review_score DECIMAL(4,2)
);

INSERT INTO mart_product_performance (
    product_category,
    total_products,
    total_items_sold,
    total_orders,
    product_revenue,
    total_freight,
    average_item_price,
    average_review_score
)
WITH category_sales AS (
    SELECT
        COALESCE(p.product_category_name, 'Unknown') AS product_category,
        COUNT(DISTINCT p.product_id) AS total_products,
        COUNT(*) AS total_items_sold,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS product_revenue,
        SUM(oi.freight_value) AS total_freight,
        AVG(oi.price) AS average_item_price
    FROM core_order_items oi
    JOIN core_orders o
        ON oi.order_id = o.order_id
    JOIN core_products p
        ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY COALESCE(p.product_category_name, 'Unknown')
),
order_reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS average_order_review
    FROM core_order_reviews
    WHERE review_score IS NOT NULL
    GROUP BY order_id
),
order_categories AS (
    SELECT DISTINCT
        oi.order_id,
        COALESCE(p.product_category_name, 'Unknown') AS product_category
    FROM core_order_items oi
    JOIN core_orders o
        ON oi.order_id = o.order_id
    JOIN core_products p
        ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
),
category_reviews AS (
    SELECT
        oc.product_category,
        AVG(r.average_order_review) AS average_review_score
    FROM order_categories oc
    JOIN order_reviews r
        ON oc.order_id = r.order_id
    GROUP BY oc.product_category
)
SELECT
    cs.product_category,
    cs.total_products,
    cs.total_items_sold,
    cs.total_orders,
    cs.product_revenue,
    cs.total_freight,
    ROUND(cs.average_item_price, 2),
    ROUND(cr.average_review_score, 2)
FROM category_sales cs
LEFT JOIN category_reviews cr
    ON cs.product_category = cr.product_category;


-- ============================================================================
-- 4. SELLER PERFORMANCE
-- Grain: one row per seller with at least one delivered item.
-- Delivery rate denominator includes only seller-order associations with both
-- actual and estimated delivery dates. Review is an order score associated
-- with the seller, not a direct rating of the seller.
-- ============================================================================
CREATE TABLE mart_seller_performance (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_state VARCHAR(10),
    total_orders INT,
    total_items_sold INT,
    product_revenue DECIMAL(15,2),
    total_freight DECIMAL(15,2),
    average_order_value DECIMAL(15,2),
    late_orders INT,
    late_delivery_rate DECIMAL(5,2),
    average_review_score DECIMAL(4,2)
);

INSERT INTO mart_seller_performance (
    seller_id,
    seller_state,
    total_orders,
    total_items_sold,
    product_revenue,
    total_freight,
    average_order_value,
    late_orders,
    late_delivery_rate,
    average_review_score
)
WITH sales AS (
    SELECT
        oi.seller_id,
        s.seller_state,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        COUNT(*) AS total_items_sold,
        SUM(oi.price) AS product_revenue,
        SUM(oi.freight_value) AS total_freight,
        SUM(oi.price) / NULLIF(COUNT(DISTINCT oi.order_id), 0)
            AS average_order_value
    FROM core_order_items oi
    JOIN core_orders o
        ON oi.order_id = o.order_id
    JOIN core_sellers s
        ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id, s.seller_state
),
delivery AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS eligible_orders,
        COUNT(DISTINCT CASE
            WHEN DATE(o.order_delivered_customer_date)
               > DATE(o.order_estimated_delivery_date)
            THEN oi.order_id
        END) AS late_orders
    FROM core_order_items oi
    JOIN core_orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
    GROUP BY oi.seller_id
),
order_reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS average_order_review
    FROM core_order_reviews
    WHERE review_score IS NOT NULL
    GROUP BY order_id
),
seller_orders AS (
    SELECT DISTINCT seller_id, order_id
    FROM core_order_items
),
seller_reviews AS (
    SELECT
        so.seller_id,
        AVG(r.average_order_review) AS average_review_score
    FROM seller_orders so
    JOIN core_orders o
        ON so.order_id = o.order_id
    JOIN order_reviews r
        ON so.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY so.seller_id
)
SELECT
    s.seller_id,
    s.seller_state,
    s.total_orders,
    s.total_items_sold,
    ROUND(s.product_revenue, 2),
    ROUND(s.total_freight, 2),
    ROUND(s.average_order_value, 2),
    COALESCE(d.late_orders, 0),
    CASE
        WHEN d.eligible_orders > 0
        THEN ROUND(d.late_orders * 100.0 / d.eligible_orders, 2)
        ELSE NULL
    END,
    ROUND(r.average_review_score, 2)
FROM sales s
LEFT JOIN delivery d
    ON s.seller_id = d.seller_id
LEFT JOIN seller_reviews r
    ON s.seller_id = r.seller_id;


-- ============================================================================
-- 5. DELIVERY PERFORMANCE
-- Grain: one row per purchase month and customer state.
-- Only delivered orders with purchase, actual-delivery and estimated-delivery
-- timestamps are included. Late means actual calendar date > estimated date.
-- ============================================================================
CREATE TABLE mart_delivery_performance (
    month_start DATE,
    customer_state VARCHAR(10),
    total_delivered_orders INT,
    late_orders INT,
    on_time_orders INT,
    late_delivery_rate DECIMAL(5,2),
    average_delivery_days DECIMAL(8,2),
    average_days_late DECIMAL(8,2),
    PRIMARY KEY (month_start, customer_state)
);

INSERT INTO mart_delivery_performance (
    month_start,
    customer_state,
    total_delivered_orders,
    late_orders,
    on_time_orders,
    late_delivery_rate,
    average_delivery_days,
    average_days_late
)
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01'),
    c.customer_state,
    COUNT(*) AS total_delivered_orders,
    SUM(CASE
        WHEN DATE(o.order_delivered_customer_date)
           > DATE(o.order_estimated_delivery_date)
        THEN 1 ELSE 0
    END) AS late_orders,
    SUM(CASE
        WHEN DATE(o.order_delivered_customer_date)
           <= DATE(o.order_estimated_delivery_date)
        THEN 1 ELSE 0
    END) AS on_time_orders,
    ROUND(
        SUM(CASE
            WHEN DATE(o.order_delivered_customer_date)
               > DATE(o.order_estimated_delivery_date)
            THEN 1 ELSE 0
        END) * 100.0 / COUNT(*),
        2
    ) AS late_delivery_rate,
    ROUND(
        AVG(TIMESTAMPDIFF(
            DAY,
            o.order_purchase_timestamp,
            o.order_delivered_customer_date
        )),
        2
    ) AS average_delivery_days,
    ROUND(
        AVG(CASE
            WHEN DATE(o.order_delivered_customer_date)
               > DATE(o.order_estimated_delivery_date)
            THEN DATEDIFF(
                DATE(o.order_delivered_customer_date),
                DATE(o.order_estimated_delivery_date)
            )
        END),
        2
    ) AS average_days_late
FROM core_orders o
JOIN core_customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01'),
    c.customer_state;


-- ============================================================================
-- 6. PAYMENT PERFORMANCE
-- Grain: one row per payment type and installment-count combination.
-- total_orders is a count of distinct orders within each group. The same order
-- can occur in multiple groups if it has multiple payment records.
-- ============================================================================
CREATE TABLE mart_payment_performance (
    payment_type VARCHAR(50),
    payment_installments INT,
    total_payment_records INT,
    total_orders INT,
    total_payment_value DECIMAL(15,2),
    average_payment_value DECIMAL(15,2),
    zero_payment_records INT,
    PRIMARY KEY (payment_type, payment_installments)
);

INSERT INTO mart_payment_performance (
    payment_type,
    payment_installments,
    total_payment_records,
    total_orders,
    total_payment_value,
    average_payment_value,
    zero_payment_records
)
SELECT
    payment_type,
    payment_installments,
    COUNT(*) AS total_payment_records,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value,
    SUM(CASE WHEN payment_value = 0 THEN 1 ELSE 0 END)
        AS zero_payment_records
FROM core_order_payments
GROUP BY payment_type, payment_installments;


-- ============================================================================
-- 7. MART BUILD VALIDATION
-- Expected row counts for the validated dataset:
-- sales 25 | customer 93358 | product 74 | seller 2970 |
-- delivery 556 | payment 28
-- ============================================================================
SELECT 'mart_sales_performance' AS mart_table, COUNT(*) AS row_count
FROM mart_sales_performance
UNION ALL
SELECT 'mart_customer_performance', COUNT(*)
FROM mart_customer_performance
UNION ALL
SELECT 'mart_product_performance', COUNT(*)
FROM mart_product_performance
UNION ALL
SELECT 'mart_seller_performance', COUNT(*)
FROM mart_seller_performance
UNION ALL
SELECT 'mart_delivery_performance', COUNT(*)
FROM mart_delivery_performance
UNION ALL
SELECT 'mart_payment_performance', COUNT(*)
FROM mart_payment_performance;

-- Reconcile delivered sales against the monthly sales MART.
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
     WHERE o.order_status = 'delivered') AS core_product_revenue,
    (SELECT ROUND(SUM(product_revenue), 2)
     FROM mart_sales_performance) AS mart_product_revenue;

-- Reconcile payment records against the payment MART.
SELECT
    (SELECT COUNT(*) FROM core_order_payments) AS core_payment_records,
    (SELECT SUM(total_payment_records)
     FROM mart_payment_performance) AS mart_payment_records,
    (SELECT ROUND(SUM(payment_value), 2)
     FROM core_order_payments) AS core_payment_value,
    (SELECT ROUND(SUM(total_payment_value), 2)
     FROM mart_payment_performance) AS mart_payment_value;

-- Check that no duplicate grain keys exist (PKs should already enforce this).
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
END OF MART CREATION SCRIPT

Expected row counts are dataset-specific checkpoints, not universal rules.
If they differ, investigate source data, prior transformations, or filtering
before treating the build as successful.
*/
