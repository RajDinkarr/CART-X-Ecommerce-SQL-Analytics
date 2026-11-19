/*
===============================================================================
CART-X | 06_Business_Analysis.sql
Purpose : Answer business questions using the completed CORE and MART layers.
Database: cartx_ecommerce
Engine  : MySQL 8.0+

EXECUTION
1. Run after 05_Mart_Creation.sql has completed successfully.
2. This is an analysis-only script: SELECT statements only.
3. It does not create, alter, update, delete, truncate, or drop data.
4. Run individual sections as needed; all queries are read-only.

METRIC DEFINITIONS
- Product revenue = SUM(order item price); freight is reported separately.
- Product revenue is NOT profit (costs, refunds and operating expenses are absent).
- Delivered-sales analyses filter to order_status = 'delivered' unless stated.
- Payment totals are payment-record values and are not automatically recognized
  sales revenue.
- Late delivery = DATE(actual delivery) > DATE(estimated delivery).
- Delivery averages using TIMESTAMPDIFF(DAY) are whole-day differences.
- Reviews are order-level customer feedback, not verified product/seller ratings.
- Avoid joining order items, payments and reviews at raw row level together:
  one-to-many joins can multiply rows and inflate sums/counts.
===============================================================================
*/

USE cartx_ecommerce;

-- ============================================================================
-- 1. SALES PERFORMANCE
-- ============================================================================

-- 1.1 Overall order-status performance.
-- Useful for understanding order outcomes across the full dataset.
SELECT
    o.order_status,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(oi.order_id) AS item_rows,
    ROUND(COALESCE(SUM(oi.price), 0), 2) AS product_value,
    ROUND(COALESCE(SUM(oi.freight_value), 0), 2) AS freight_value
FROM core_orders o
LEFT JOIN core_order_items oi
    ON o.order_id = oi.order_id
GROUP BY o.order_status
ORDER BY total_orders DESC;

-- 1.2 Monthly sales trend from the sales MART.
SELECT
    month_start,
    total_orders,
    delivered_orders,
    canceled_orders,
    total_items_sold,
    product_revenue,
    total_freight,
    average_order_value
FROM mart_sales_performance
ORDER BY month_start;

-- 1.3 Rank months by delivered product revenue.
SELECT
    month_start,
    delivered_orders,
    product_revenue,
    average_order_value,
    DENSE_RANK() OVER (ORDER BY product_revenue DESC) AS revenue_rank
FROM mart_sales_performance
ORDER BY revenue_rank, month_start;

-- 1.4 Monthly cancellation rate.
-- Denominator is all orders in that purchase month.
SELECT
    month_start,
    total_orders,
    canceled_orders,
    ROUND(canceled_orders * 100.0 / NULLIF(total_orders, 0), 2)
        AS cancellation_rate_pct
FROM mart_sales_performance
ORDER BY month_start;

-- ============================================================================
-- 2. CUSTOMER PERFORMANCE
-- ============================================================================

-- 2.1 Overall customer and repeat-customer summary.
-- The customer MART includes customers with delivered sales only.
SELECT
    COUNT(*) AS delivered_customers,
    SUM(repeat_customer_flag = 0) AS one_time_customers,
    SUM(repeat_customer_flag = 1) AS repeat_customers,
    ROUND(AVG(total_product_spending), 2) AS average_customer_spending,
    ROUND(AVG(total_orders), 2) AS average_delivered_orders_per_customer,
    ROUND(
        SUM(repeat_customer_flag = 1) * 100.0 / COUNT(*),
        2
    ) AS repeat_customer_rate_pct
FROM mart_customer_performance;

-- 2.2 Customer spending segments.
SELECT
    CASE
        WHEN total_product_spending < 100 THEN 'Below 100'
        WHEN total_product_spending < 500 THEN '100 to 499.99'
        WHEN total_product_spending < 1000 THEN '500 to 999.99'
        WHEN total_product_spending < 5000 THEN '1000 to 4999.99'
        ELSE '5000 and above'
    END AS spending_segment,
    COUNT(*) AS customers,
    ROUND(SUM(total_product_spending), 2) AS segment_product_spending,
    ROUND(AVG(total_product_spending), 2) AS average_spending,
    SUM(repeat_customer_flag = 1) AS repeat_customers,
    ROUND(
        SUM(repeat_customer_flag = 1) * 100.0 / COUNT(*),
        2
    ) AS repeat_rate_pct
FROM mart_customer_performance
GROUP BY spending_segment
ORDER BY MIN(total_product_spending);

-- 2.3 Highest-spending customers.
-- Customer IDs are dataset identifiers, not personally identifying names.
SELECT
    customer_unique_id,
    total_orders,
    total_product_spending,
    average_order_value,
    first_purchase_date,
    last_purchase_date,
    repeat_customer_flag
FROM mart_customer_performance
ORDER BY total_product_spending DESC
LIMIT 20;

-- 2.4 Repeat-customer distribution by order count.
SELECT
    total_orders,
    COUNT(*) AS customers,
    ROUND(AVG(total_product_spending), 2) AS average_customer_spending
FROM mart_customer_performance
GROUP BY total_orders
ORDER BY total_orders;

-- ============================================================================
-- 3. PRODUCT CATEGORY PERFORMANCE
-- ============================================================================

-- 3.1 Category performance overview.
SELECT
    product_category,
    total_products,
    total_items_sold,
    total_orders,
    product_revenue,
    total_freight,
    average_item_price,
    average_review_score
FROM mart_product_performance
ORDER BY product_revenue DESC;

-- 3.2 Top 10 categories by delivered product revenue.
SELECT
    product_category,
    total_items_sold,
    total_orders,
    product_revenue,
    average_item_price,
    average_review_score
FROM mart_product_performance
ORDER BY product_revenue DESC
LIMIT 10;

-- 3.3 Categories with the largest item volumes.
SELECT
    product_category,
    total_items_sold,
    total_orders,
    product_revenue,
    average_item_price
FROM mart_product_performance
ORDER BY total_items_sold DESC
LIMIT 10;

-- 3.4 Review-score comparison by category.
-- This is an order-review association, not a direct product rating.
SELECT
    product_category,
    total_orders,
    average_review_score
FROM mart_product_performance
WHERE average_review_score IS NOT NULL
ORDER BY average_review_score ASC, total_orders DESC;

-- 3.5 Freight as a share of product value.
-- This is a freight-to-product-value ratio, NOT profit margin.
SELECT
    product_category,
    product_revenue,
    total_freight,
    ROUND(
        total_freight * 100.0 / NULLIF(product_revenue, 0),
        2
    ) AS freight_to_product_value_pct
FROM mart_product_performance
ORDER BY freight_to_product_value_pct DESC;

-- ============================================================================
-- 4. SELLER PERFORMANCE
-- ============================================================================

-- 4.1 Top 20 sellers by delivered product revenue.
SELECT
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
FROM mart_seller_performance
ORDER BY product_revenue DESC
LIMIT 20;

-- 4.2 Seller comparison using a minimum order threshold.
-- The threshold reduces the influence of sellers with very small samples.
SELECT
    seller_id,
    seller_state,
    total_orders,
    product_revenue,
    average_order_value,
    late_delivery_rate,
    average_review_score
FROM mart_seller_performance
WHERE total_orders >= 100
ORDER BY average_order_value DESC
LIMIT 20;

-- 4.3 Sellers with the highest late-delivery rates among sellers with
-- at least 100 delivered orders and a calculable delivery rate.
SELECT
    seller_id,
    seller_state,
    total_orders,
    late_orders,
    late_delivery_rate
FROM mart_seller_performance
WHERE total_orders >= 100
  AND late_delivery_rate IS NOT NULL
ORDER BY late_delivery_rate DESC
LIMIT 20;

-- 4.4 Aggregate delivered performance by seller state.
-- Counts are seller-order associations; an order can involve multiple sellers.
SELECT
    seller_state,
    COUNT(*) AS sellers,
    SUM(total_orders) AS seller_order_associations,
    SUM(total_items_sold) AS item_rows,
    ROUND(SUM(product_revenue), 2) AS product_revenue,
    ROUND(SUM(total_freight), 2) AS freight_value,
    ROUND(
        SUM(product_revenue) * 100.0 /
        NULLIF(SUM(SUM(product_revenue)) OVER (), 0),
        2
    ) AS share_of_seller_product_revenue_pct
FROM mart_seller_performance
GROUP BY seller_state
ORDER BY product_revenue DESC;

-- ============================================================================
-- 5. DELIVERY PERFORMANCE
-- ============================================================================

-- 5.1 Overall delivery duration for delivered orders with both timestamps.
-- TIMESTAMPDIFF(DAY) returns completed whole days.
SELECT
    COUNT(*) AS eligible_delivered_orders,
    ROUND(AVG(TIMESTAMPDIFF(
        DAY,
        order_purchase_timestamp,
        order_delivered_customer_date
    )), 2) AS average_delivery_days,
    MIN(TIMESTAMPDIFF(
        DAY,
        order_purchase_timestamp,
        order_delivered_customer_date
    )) AS minimum_delivery_days,
    MAX(TIMESTAMPDIFF(
        DAY,
        order_purchase_timestamp,
        order_delivered_customer_date
    )) AS maximum_delivery_days
FROM core_orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;

-- 5.2 Overall late/on-time delivery summary.
-- Uses the same calendar-date rule as the delivery MART.
SELECT
    COUNT(*) AS eligible_delivered_orders,
    SUM(DATE(order_delivered_customer_date) >
        DATE(order_estimated_delivery_date)) AS late_orders,
    SUM(DATE(order_delivered_customer_date) <=
        DATE(order_estimated_delivery_date)) AS on_time_or_early_orders,
    ROUND(
        SUM(DATE(order_delivered_customer_date) >
            DATE(order_estimated_delivery_date)) * 100.0 / COUNT(*),
        2
    ) AS late_delivery_rate_pct
FROM core_orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

-- 5.3 Monthly late-delivery trend.
SELECT
    month_start,
    SUM(total_delivered_orders) AS eligible_delivered_orders,
    SUM(late_orders) AS late_orders,
    SUM(on_time_orders) AS on_time_or_early_orders,
    ROUND(
        SUM(late_orders) * 100.0 /
        NULLIF(SUM(total_delivered_orders), 0),
        2
    ) AS weighted_late_delivery_rate_pct
FROM mart_delivery_performance
GROUP BY month_start
ORDER BY month_start;

-- 5.4 Customer-state late-delivery performance across the full period.
-- Weighted rate is calculated from summed order counts, not an average
-- of monthly percentages.
SELECT
    customer_state,
    SUM(total_delivered_orders) AS eligible_delivered_orders,
    SUM(late_orders) AS late_orders,
    ROUND(
        SUM(late_orders) * 100.0 /
        NULLIF(SUM(total_delivered_orders), 0),
        2
    ) AS weighted_late_delivery_rate_pct
FROM mart_delivery_performance
GROUP BY customer_state
HAVING SUM(total_delivered_orders) >= 500
ORDER BY weighted_late_delivery_rate_pct DESC;

-- 5.5 State-level delivery performance for March 2018.
SELECT
    customer_state,
    SUM(total_delivered_orders) AS eligible_delivered_orders,
    SUM(late_orders) AS late_orders,
    ROUND(
        SUM(late_orders) * 100.0 /
        NULLIF(SUM(total_delivered_orders), 0),
        2
    ) AS late_delivery_rate_pct
FROM mart_delivery_performance
WHERE month_start = '2018-03-01'
GROUP BY customer_state
HAVING SUM(total_delivered_orders) >= 30
ORDER BY late_delivery_rate_pct DESC;

-- 5.6 Compare average order review by delivery outcome.
-- Each order is first reduced to one average review score to avoid giving
-- orders with multiple review rows extra weight.
WITH order_reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS average_order_review
    FROM core_order_reviews
    WHERE review_score IS NOT NULL
    GROUP BY order_id
),
delivery_outcome AS (
    SELECT
        order_id,
        CASE
            WHEN DATE(order_delivered_customer_date) >
                 DATE(order_estimated_delivery_date)
            THEN 'Late'
            ELSE 'On time or early'
        END AS delivery_status
    FROM core_orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    d.delivery_status,
    COUNT(*) AS orders_with_reviews,
    ROUND(AVG(r.average_order_review), 2) AS average_review_score
FROM delivery_outcome d
JOIN order_reviews r
    ON d.order_id = r.order_id
GROUP BY d.delivery_status
ORDER BY average_review_score;

-- ============================================================================
-- 6. PAYMENT PERFORMANCE
-- ============================================================================

-- 6.1 Payment-method summary.
-- Counts are payment records. Orders may have multiple payment records.
SELECT
    payment_type,
    SUM(total_payment_records) AS payment_records,
    SUM(total_orders) AS payment_group_order_associations,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,
    ROUND(
        SUM(total_payment_value) /
        NULLIF(SUM(total_payment_records), 0),
        2
    ) AS average_payment_record_value,
    SUM(zero_payment_records) AS zero_payment_records
FROM mart_payment_performance
GROUP BY payment_type
ORDER BY total_payment_value DESC;

-- 6.2 Installment pattern.
SELECT
    payment_installments,
    SUM(total_payment_records) AS payment_records,
    SUM(total_orders) AS payment_group_order_associations,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,
    ROUND(
        SUM(total_payment_records) * 100.0 /
        NULLIF((SELECT COUNT(*) FROM core_order_payments), 0),
        2
    ) AS share_of_all_payment_records_pct
FROM mart_payment_performance
GROUP BY payment_installments
ORDER BY payment_records DESC;

-- 6.3 Payment type and installment combination.
SELECT
    payment_type,
    payment_installments,
    total_payment_records,
    total_orders,
    total_payment_value,
    average_payment_value,
    zero_payment_records
FROM mart_payment_performance
ORDER BY total_payment_value DESC;

-- 6.4 Inspect zero-payment records in the CORE layer.
SELECT
    payment_type,
    payment_installments,
    COUNT(*) AS zero_payment_records
FROM core_order_payments
WHERE payment_value = 0
GROUP BY payment_type, payment_installments
ORDER BY zero_payment_records DESC;

-- ============================================================================
-- 7. DATA LIMITATION CASE STUDY: UNAVAILABLE ORDERS
-- These queries document a source-data anomaly; they do not infer that
-- customers were incorrectly charged or that payments are recognized revenue.
-- ============================================================================

-- 7.1 How many unavailable orders have item rows?
SELECT
    COUNT(DISTINCT o.order_id) AS unavailable_orders,
    COUNT(DISTINCT oi.order_id) AS unavailable_orders_with_items,
    COUNT(oi.order_id) AS item_rows
FROM core_orders o
LEFT JOIN core_order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'unavailable';

-- 7.2 Compare CORE and STG item presence for unavailable orders.
-- A matching result indicates the absence was already present in source data.
SELECT
    COUNT(DISTINCT o.order_id) AS unavailable_orders,
    COUNT(DISTINCT stg.order_id) AS unavailable_orders_with_staging_items,
    COUNT(stg.order_id) AS staging_item_rows
FROM core_orders o
LEFT JOIN stg_order_items stg
    ON o.order_id = stg.order_id
WHERE o.order_status = 'unavailable';

-- 7.3 Payment records associated with unavailable orders.
-- This is a diagnostic reconciliation, not a conclusion about refunds/charges.
SELECT
    COUNT(DISTINCT o.order_id) AS unavailable_orders,
    COUNT(DISTINCT p.order_id) AS orders_with_payment_records,
    COUNT(p.payment_id) AS payment_records,
    ROUND(SUM(p.payment_value), 2) AS recorded_payment_value
FROM core_orders o
LEFT JOIN core_order_payments p
    ON o.order_id = p.order_id
WHERE o.order_status = 'unavailable';

-- ============================================================================
-- END OF BUSINESS ANALYSIS
-- ============================================================================
