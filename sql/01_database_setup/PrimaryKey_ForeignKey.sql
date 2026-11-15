

--A Primary Key is a column (or combination of columns) that uniquely identifies every record in a table.
--Think of it as a person's unique ID number.

--A Foreign Key is a column in one table that refers to a Primary Key (or another unique key) in another table.
--Think of it as a connection between two tables.

USE Olist_Ecommerce;
GO

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
ORDER BY
    TABLE_NAME,
    ORDINAL_POSITION;


---------------------------------Check For PrimaryKey----------------------------------------
USE Olist_Ecommerce;
GO

-- Primary key candidate checks

SELECT 'customers.customer_id' AS column_name,
       COUNT(*) AS total_rows,
       COUNT(customer_id) AS non_null_rows,
       COUNT(DISTINCT customer_id) AS unique_values
FROM customers

UNION ALL

SELECT 'orders.order_id',
       COUNT(*),
       COUNT(order_id),
       COUNT(DISTINCT order_id)
FROM orders

UNION ALL

SELECT 'products.product_id',
       COUNT(*),
       COUNT(product_id),
       COUNT(DISTINCT product_id)
FROM products

UNION ALL

SELECT 'sellers.seller_id',
       COUNT(*),
       COUNT(seller_id),
       COUNT(DISTINCT seller_id)
FROM sellers;

---------------------------------Create PrimaryKey----------------------------------------

USE Olist_Ecommerce;
GO

-- Customers
ALTER TABLE customers
ALTER COLUMN customer_id VARCHAR(32) NOT NULL;

ALTER TABLE customers
ADD CONSTRAINT PK_customers
PRIMARY KEY (customer_id);


-- Orders
ALTER TABLE orders
ALTER COLUMN order_id VARCHAR(32) NOT NULL;

ALTER TABLE orders
ADD CONSTRAINT PK_orders
PRIMARY KEY (order_id);


-- Products
ALTER TABLE products
ALTER COLUMN product_id VARCHAR(32) NOT NULL;

ALTER TABLE products
ADD CONSTRAINT PK_products
PRIMARY KEY (product_id);


-- Sellers
ALTER TABLE sellers
ALTER COLUMN seller_id VARCHAR(32) NOT NULL;

ALTER TABLE sellers
ADD CONSTRAINT PK_sellers
PRIMARY KEY (seller_id);

---------------------------------Check For ForeignKey----------------------------------------

SELECT COUNT(*) AS unmatched_customers
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


---------------------------------Create ForeignKey----------------------------------------


USE Olist_Ecommerce;
GO

-- 1. Orders → Customers
ALTER TABLE orders
ADD CONSTRAINT FK_orders_customers
FOREIGN KEY (customer_id)
REFERENCES customers(customer_id);


-- 2. Order Items → Orders
ALTER TABLE order_items
ADD CONSTRAINT FK_order_items_orders
FOREIGN KEY (order_id)
REFERENCES orders(order_id);


-- 3. Order Items → Products
ALTER TABLE order_items
ADD CONSTRAINT FK_order_items_products
FOREIGN KEY (product_id)
REFERENCES products(product_id);


-- 4. Order Items → Sellers
ALTER TABLE order_items
ADD CONSTRAINT FK_order_items_sellers
FOREIGN KEY (seller_id)
REFERENCES sellers(seller_id);


-- 5. Payments → Orders
ALTER TABLE payments
ADD CONSTRAINT FK_payments_orders
FOREIGN KEY (order_id)
REFERENCES orders(order_id);


-- 6. Reviews → Orders
ALTER TABLE reviews
ADD CONSTRAINT FK_reviews_orders
FOREIGN KEY (order_id)
REFERENCES orders(order_id);

---------------------------------Check Relationship----------------------------------------

USE Olist_Ecommerce;
GO

SELECT
    fk.name AS foreign_key_name,
    OBJECT_NAME(fk.parent_object_id) AS child_table,
    COL_NAME(
        fkc.parent_object_id,
        fkc.parent_column_id
    ) AS child_column,
    OBJECT_NAME(fk.referenced_object_id) AS parent_table,
    COL_NAME(
        fkc.referenced_object_id,
        fkc.referenced_column_id
    ) AS parent_column
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc
    ON fk.object_id = fkc.constraint_object_id
ORDER BY child_table, foreign_key_name;
