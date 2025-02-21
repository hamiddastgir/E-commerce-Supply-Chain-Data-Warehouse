-- Creating a staging schema

CREATE SCHEMA IF NOT EXISTS staging;

-- 

CREATE TABLE staging.orders (
    order_id TEXT,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);


CREATE TABLE staging.customers (
    customer_id TEXT,
    customer_unique_id TEXT,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state CHAR(2)
);

CREATE TABLE staging.products (
    product_id TEXT,
    product_category_name TEXT,
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);

CREATE TABLE staging.order_reviews (
    review_id TEXT,
    order_id TEXT,
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

CREATE TABLE staging.order_items (
    order_id TEXT,
    order_item_id INTEGER,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TIMESTAMP,
    price NUMERIC(10,2),
    freight_value NUMERIC(10,2)
);

CREATE TABLE staging.geolocation (
    geolocation_zip_code_prefix TEXT,
    geolocation_lat DOUBLE PRECISION,
    geolocation_lng DOUBLE PRECISION,
    geolocation_city TEXT,
    geolocation_state CHAR(2)
);

CREATE TABLE staging.sellers (
    seller_id TEXT,
    seller_zip_code_prefix TEXT,
    seller_city TEXT,
    seller_state CHAR(2)
);

CREATE TABLE staging.order_payments (
    order_id TEXT,
    payment_sequential INTEGER,
    payment_type TEXT,
    payment_installments INTEGER,
    payment_value NUMERIC(10,2)
);

CREATE TABLE staging.product_category_name_translation (
    product_category_name TEXT,
    product_category_name_english TEXT
);

-- Copying Files

COPY staging.orders
FROM '/Users/hamiddastgir/Hamid/PostgreSQL/SQL Project/Brazillian Dataset/orders.csv'
WITH CSV HEADER DELIMITER ',';

COPY staging.customers
FROM '/Users/hamiddastgir/Hamid/PostgreSQL/SQL Project/Brazillian Dataset/customers.csv'
WITH CSV HEADER DELIMITER ',';

COPY staging.order_items
FROM '/Users/hamiddastgir/Hamid/PostgreSQL/SQL Project/Brazillian Dataset/order_items.csv'
WITH CSV HEADER DELIMITER ',';

COPY staging.order_payments
FROM '/Users/hamiddastgir/Hamid/PostgreSQL/SQL Project/Brazillian Dataset/order_payments.csv'
WITH CSV HEADER DELIMITER ',';

COPY staging.reviews
FROM '/Users/hamiddastgir/Hamid/PostgreSQL/SQL Project/Brazillian Dataset/reviews.csv'
WITH CSV HEADER DELIMITER ',';

COPY staging.products
FROM '/Users/hamiddastgir/Hamid/PostgreSQL/SQL Project/Brazillian Dataset/products.csv'
WITH CSV HEADER DELIMITER ',';

COPY staging.product_category_name_translation
FROM '/Users/hamiddastgir/Hamid/PostgreSQL/SQL Project/Brazillian Dataset/product_category_name_translation.csv'
WITH CSV HEADER DELIMITER ',';

COPY staging.sellers
FROM '/Users/hamiddastgir/Hamid/PostgreSQL/SQL Project/Brazillian Dataset/sellers.csv'
WITH CSV HEADER DELIMITER ',';

COPY staging.geolocation
FROM '/Users/hamiddastgir/Hamid/PostgreSQL/SQL Project/Brazillian Dataset/geolocation.csv'
WITH CSV HEADER DELIMITER ',';

-- Verifying Row Count

SELECT COUNT(*) FROM staging.orders;
SELECT COUNT(*) FROM staging.customers;
SELECT COUNT(*) FROM staging.order_items;
SELECT COUNT(*) FROM staging.order_payments;
SELECT COUNT(*) FROM staging.reviews;
SELECT COUNT(*) FROM staging.products;
SELECT COUNT(*) FROM staging.product_category_name_translation;
SELECT COUNT(*) FROM staging.sellers;
SELECT COUNT(*) FROM staging.geolocation;

-- Done

-- Checking for null values

SELECT COUNT(*) AS total_rows,
       COUNT(order_id) AS non_null_orders,
       COUNT(customer_id) AS non_null_customers,
       COUNT(order_purchase_timestamp) AS non_null_purchase_dates
FROM staging.orders;


SELECT COUNT(*) AS total_rows,
       COUNT(customer_id) AS non_null_customers,
       COUNT(customer_unique_id) AS non_null_unique_customers
FROM staging.customers;

SELECT COUNT(*) AS total_rows,
       COUNT(product_id) AS non_null_products,
       COUNT(product_category_name) AS non_null_categories,
       COUNT(product_weight_g) AS non_null_weight
FROM staging.products;

SELECT product_id, COUNT(*)
FROM staging.products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- Checking Valid Date ranges

SELECT MIN(order_purchase_timestamp) AS earliest_order, 
       MAX(order_purchase_timestamp) AS latest_order
FROM staging.orders;


SELECT MIN(review_creation_date) AS earliest_review, 
       MAX(review_creation_date) AS latest_review
FROM staging.reviews;

-- Detecting Duplicate Primary Keys

SELECT order_id, COUNT(*)
FROM staging.orders
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT customer_id, COUNT(*)
FROM staging.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Checking for Outliers

SELECT MIN(product_weight_g) AS min_weight,
       MAX(product_weight_g) AS max_weight
FROM staging.products;

SELECT MIN(freight_value) AS min_freight,
       MAX(freight_value) AS max_freight
FROM staging.olist_order_items;

-- Products table's category field had null values. Fixing the null values within Product table by setting values as unknown

UPDATE staging.products
SET product_category_name = 'unknown'
WHERE product_category_name IS NULL;

-- Checking median of product_weight_g and imputing it with the median weight

SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY product_weight_g) 
FROM staging.products
WHERE product_weight_g IS NOT NULL;

UPDATE staging.products
SET product_weight_g = (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY product_weight_g) 
                        FROM staging.products WHERE product_weight_g IS NOT NULL)
WHERE product_weight_g IS NULL;

-- Query to check if all NULL values have been handles

SELECT product_id, COUNT(*)
FROM staging.products
GROUP BY product_id
HAVING COUNT(*) > 1; -- no null values


-- Create dw Schema

CREATE SCHEMA IF NOT EXISTS dw;

-- Create Dimension Tables

-- dim_customer

CREATE TABLE dw.dim_customer (
    customer_key SERIAL PRIMARY KEY,
    customer_id TEXT UNIQUE NOT NULL,
    customer_unique_id TEXT,
    customer_city TEXT,
    customer_state TEXT,
    effective_start_date DATE DEFAULT CURRENT_DATE,
    effective_end_date DATE,
    is_current BOOLEAN DEFAULT TRUE
);

-- dim_product

CREATE TABLE dw.dim_product (
    product_key SERIAL PRIMARY KEY,
    product_id TEXT UNIQUE NOT NULL,
    product_category_name TEXT,
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

-- dim_seller

CREATE TABLE dw.dim_seller (
    seller_key SERIAL PRIMARY KEY,
    seller_id TEXT UNIQUE NOT NULL,
    seller_city TEXT,
    seller_state TEXT
);

-- dim_date

CREATE TABLE dw.dim_date (
    date_key SERIAL PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year INT,
    quarter INT,
    month INT,
    day INT,
    day_of_week TEXT,
    is_weekend BOOLEAN
);

-- dim_geolocation

CREATE TABLE dw.dim_geolocation (
    geolocation_key SERIAL PRIMARY KEY,
    zip_code_prefix TEXT UNIQUE NOT NULL,
    latitude NUMERIC(10, 6),
    longitude NUMERIC(10, 6),
    city TEXT,
    state TEXT
);


-- dim_category

CREATE TABLE dw.dim_category (
    category_key SERIAL PRIMARY KEY,
    product_category_name TEXT UNIQUE NOT NULL,
    product_category_name_english TEXT
);

-- CREATE FACT Tables

-- fact_orders

CREATE TABLE dw.fact_orders (
    order_key SERIAL PRIMARY KEY,
    order_id TEXT UNIQUE NOT NULL,
    customer_key INT NOT NULL,
    order_status TEXT,
    order_purchase_date DATE,
    order_approved_date DATE,
    order_delivered_date DATE,
    order_estimated_delivery_date DATE,
    FOREIGN KEY (customer_key) REFERENCES dw.dim_customer(customer_key)
);

-- fact_order_items

CREATE TABLE dw.fact_order_items (
    order_item_key SERIAL PRIMARY KEY,
    order_id TEXT NOT NULL,
    product_key INT NOT NULL,
    seller_key INT NOT NULL,
    price NUMERIC(10, 2),
    freight_value NUMERIC(10, 2),
    FOREIGN KEY (product_key) REFERENCES dw.dim_product(product_key),
    FOREIGN KEY (seller_key) REFERENCES dw.dim_seller(seller_key)
);

-- fact_payments

CREATE TABLE dw.fact_payments (
    payment_key SERIAL PRIMARY KEY,
    order_id TEXT NOT NULL,
    payment_type TEXT,
    payment_installments INT,
    payment_value NUMERIC(10, 2)
);

-- fact_reviews

CREATE TABLE dw.fact_reviews (
    review_key SERIAL PRIMARY KEY,
    order_id TEXT NOT NULL,
    review_score INT,
    review_comment TEXT,
    review_creation_date DATE
);

-- 3: Move Data from Staging to DW

-- ETL for Dimension Tables

-- dim_customer

INSERT INTO dw.dim_customer (customer_id, customer_unique_id, customer_city, customer_state)
SELECT DISTINCT customer_id, customer_unique_id, customer_city, customer_state
FROM staging.customers;

-- dim_product

INSERT INTO dw.dim_product (product_id, product_category_name, product_name_length, product_description_length, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm)
SELECT DISTINCT product_id, COALESCE(product_category_name, 'unknown'), product_name_length, product_description_length, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm
FROM staging.products;

