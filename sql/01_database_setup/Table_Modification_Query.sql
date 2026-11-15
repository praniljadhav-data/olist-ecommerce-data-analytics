
USE Olist_Ecommerce;
-------------------------------------------Table length modification
GO

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    /* 1. CUSTOMERS */
    ALTER TABLE customers ALTER COLUMN customer_id VARCHAR(32) NULL;
    ALTER TABLE customers ALTER COLUMN customer_unique_id VARCHAR(32) NULL;
    ALTER TABLE customers ALTER COLUMN customer_zip_code_prefix VARCHAR(5) NULL;
    ALTER TABLE customers ALTER COLUMN customer_city VARCHAR(32) NULL;
    ALTER TABLE customers ALTER COLUMN customer_state VARCHAR(2) NULL;

    UPDATE customers
    SET customer_zip_code_prefix =
        RIGHT('00000' + customer_zip_code_prefix, 5)
    WHERE customer_zip_code_prefix IS NOT NULL;


    /* 2. ORDERS */
    ALTER TABLE orders ALTER COLUMN order_id VARCHAR(32) NULL;
    ALTER TABLE orders ALTER COLUMN customer_id VARCHAR(32) NULL;
    ALTER TABLE orders ALTER COLUMN order_status VARCHAR(11) NULL;


    /* 3. PRODUCTS */
    ALTER TABLE products ALTER COLUMN product_id VARCHAR(32) NULL;
    ALTER TABLE products ALTER COLUMN product_category_name VARCHAR(100) NULL;
    ALTER TABLE products ALTER COLUMN product_name_lenght INT NULL;
    ALTER TABLE products ALTER COLUMN product_description_lenght INT NULL;
    ALTER TABLE products ALTER COLUMN product_photos_qty INT NULL;
    ALTER TABLE products ALTER COLUMN product_weight_g INT NULL;
    ALTER TABLE products ALTER COLUMN product_length_cm INT NULL;
    ALTER TABLE products ALTER COLUMN product_height_cm INT NULL;
    ALTER TABLE products ALTER COLUMN product_width_cm INT NULL;


    /* 4. SELLERS */
    ALTER TABLE sellers ALTER COLUMN seller_id VARCHAR(32) NULL;
    ALTER TABLE sellers ALTER COLUMN seller_zip_code_prefix VARCHAR(5) NULL;
    ALTER TABLE sellers ALTER COLUMN seller_city VARCHAR(40) NULL;
    ALTER TABLE sellers ALTER COLUMN seller_state VARCHAR(2) NULL;

    UPDATE sellers
    SET seller_zip_code_prefix =
        RIGHT('00000' + seller_zip_code_prefix, 5)
    WHERE seller_zip_code_prefix IS NOT NULL;


    /* 5. ORDER ITEMS */
    ALTER TABLE order_items ALTER COLUMN order_id VARCHAR(32) NULL;
    ALTER TABLE order_items ALTER COLUMN order_item_id INT NULL;
    ALTER TABLE order_items ALTER COLUMN product_id VARCHAR(32) NULL;
    ALTER TABLE order_items ALTER COLUMN seller_id VARCHAR(32) NULL;
    ALTER TABLE order_items ALTER COLUMN price DECIMAL(10,2) NULL;
    ALTER TABLE order_items ALTER COLUMN freight_value DECIMAL(10,2) NULL;


    /* 6. PAYMENTS */
    ALTER TABLE payments ALTER COLUMN order_id VARCHAR(32) NULL;
    ALTER TABLE payments ALTER COLUMN payment_sequential INT NULL;
    ALTER TABLE payments ALTER COLUMN payment_type VARCHAR(20) NULL;
    ALTER TABLE payments ALTER COLUMN payment_installments INT NULL;
    ALTER TABLE payments ALTER COLUMN payment_value DECIMAL(10,2) NULL;


    /* 7. REVIEWS */
    ALTER TABLE reviews ALTER COLUMN review_id VARCHAR(32) NULL;
    ALTER TABLE reviews ALTER COLUMN order_id VARCHAR(32) NULL;
    ALTER TABLE reviews ALTER COLUMN review_score TINYINT NULL;
    ALTER TABLE reviews ALTER COLUMN review_comment_title VARCHAR(26) NULL;
    ALTER TABLE reviews ALTER COLUMN review_comment_message VARCHAR(208) NULL;


    /* 8. GEOLOCATION */
    ALTER TABLE geolocation ALTER COLUMN geolocation_zip_code_prefix VARCHAR(5) NULL;
    ALTER TABLE geolocation ALTER COLUMN geolocation_city VARCHAR(38) NULL;
    ALTER TABLE geolocation ALTER COLUMN geolocation_state VARCHAR(2) NULL;

    UPDATE geolocation
    SET geolocation_zip_code_prefix =
        RIGHT('00000' + geolocation_zip_code_prefix, 5)
    WHERE geolocation_zip_code_prefix IS NOT NULL;


    /* 9. CATEGORY TRANSLATION */
    ALTER TABLE category_translation
        ALTER COLUMN product_category_name VARCHAR(50) NULL;

    ALTER TABLE category_translation
        ALTER COLUMN product_category_name_english VARCHAR(50) NULL;


    COMMIT TRANSACTION;

    PRINT 'Schema migration completed successfully.';

END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
