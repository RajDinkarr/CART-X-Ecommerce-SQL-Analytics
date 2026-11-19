-- =========================================================
-- PROJECT: CART-X
-- FILE: 01_Database_Setup.sql
-- PURPOSE: Create and select the project database.
-- REQUIREMENT: MySQL 8.0+
-- =========================================================

CREATE DATABASE IF NOT EXISTS cartx_ecommerce
CHARACTER SET utf8mb4
COLLATE utf8mb4_0900_ai_ci;

USE cartx_ecommerce;

-- Confirm the MySQL version and active database.
SELECT
    VERSION() AS mysql_version,
    DATABASE() AS active_database;
