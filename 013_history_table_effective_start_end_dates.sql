-----------------------------------------------------------------------------------
-- Script 013                                                                 
--       
-- HISTORY TABLE (EFFECTIVE START, END DATES)                    
--     
-- #1  A promotion table creation and usage example
-- #2  A temporal table implementation example
--                                                                              
-----------------------------------------------------------------------------------
USE OnlineStore;
GO


-----------------------------------------------------------------------------------
-- #1 A promotion table creation and usage example
-----------------------------------------------------------------------------------

-- Creates a promotion table
CREATE TABLE production.promotion (
	product_id				VARCHAR(7)		NOT NULL,
	effective_start_date	DATE			NOT NULL,
	effective_end_date		DATE			NOT NULL,
	discount_percent		INT				NOT NULL,
	CONSTRAINT pk_promotion PRIMARY KEY (product_id, effective_start_date DESC),
	CONSTRAINT fk_promotion_product 
		FOREIGN KEY (product_id) 
			REFERENCES production.product (product_id) 
			ON DELETE CASCADE 
			ON UPDATE CASCADE,
	CONSTRAINT chk_promotion_discount_percent_between_0_and_100 
		CHECK (discount_percent >= 0 AND discount_percent <= 100)
);
GO


-- Adds list_price, discount_percent columns 
-- and additional constraints to the order_item table
ALTER TABLE sales.order_item ADD
	list_price DECIMAL(10, 2) NULL,

	discount_percent INT NOT NULL 
		CONSTRAINT df_order_item_discount_percent_0	DEFAULT(0)
GO

ALTER TABLE sales.order_item ADD 
	CONSTRAINT chk_order_item_list_price_greater_or_equal_to_0
		CHECK (list_price >= 0),

	CONSTRAINT chk_order_item_discount_percent_between_0_and_100 
		CHECK (discount_percent >= 0 AND discount_percent <= 100)
GO


-- Populates the order_item table with product prices
-- and sets discounts to 0
UPDATE sales.order_item
	SET list_price = p.list_price,
		discount_percent = 0
FROM sales.order_item oi
	INNER JOIN production.product p ON oi.product_id = p.product_id
GO

-- Sets the list_price to non-nullable type
ALTER TABLE sales.order_item ALTER COLUMN list_price DECIMAL(10, 2) NOT NULL;
GO


--
-- The promotion table usage example
--
BEGIN TRANSACTION;
 
INSERT INTO [production].[product]
  (product_id, name, compatible_os, required_disk_space, required_ram, weight, height, width, length, product_category_id, list_price, vendor_id)
VALUES ('PRD0999', 'Product Name', 'Vendor Name', 500, 20.0, 4.0, null, null, null, 1, 1, 100.00);


INSERT INTO production.promotion (product_id, effective_start_date, effective_end_date, discount_percent)
VALUES 
-- Promotions for PRD0001
('PRD0999', '2024-01-01', '2024-01-31', 5),
('PRD0999', '2024-02-01', '2024-02-29', 10),
('PRD0999', '2024-03-01', '2024-03-31', 15),
('PRD0999', '2024-04-01', '2024-04-30', 20),
('PRD0999', '2024-05-01', '2024-05-31', 0),
('PRD0999', '2024-06-01', '2024-06-30', 25);

-- Insert orders with quantities
SET IDENTITY_INSERT sales.[order] ON;
INSERT INTO sales.[order] (order_id, customer_id, order_status_type_id, order_date)
VALUES 
-- Orders for PRD0999
(20007, 2, 4, '2024-01-10'),
(20008, 2, 4, '2024-02-10'),
(20009, 2, 4, '2024-03-10'),
(20010, 2, 4, '2024-04-10'),
(20011, 2, 4, '2024-05-10'),
(20012, 2, 4, '2024-06-10');
SET IDENTITY_INSERT sales.[order] OFF;

-- Inserts order items
INSERT INTO sales.order_item (order_id, item_id, product_id, quantity, list_price, discount_percent)
VALUES 
(20008, 1, 'PRD0999', 18, 100.00, 10),
(20009, 1, 'PRD0999', 29, 100.00, 15),
(20010, 1, 'PRD0999', 30, 100.00, 20),
(20011, 1, 'PRD0999', 15, 100.00,  0),
(20012, 1, 'PRD0999', 32, 100.00, 25);


-- Calculates promotion performance per distinct promotion period
 SELECT *
FROM (
    SELECT
        p.product_id,
        p.effective_start_date AS start_date,
        p.effective_end_date AS end_date,
        p.discount_percent,
        SUM(oi.quantity) AS total_sold_quantity,
        SUM(oi.quantity * oi.list_price) AS total_original_revenue,
        SUM(oi.quantity * oi.list_price * (1 - p.discount_percent / 100.0)) AS total_discounted_revenue,
        RANK() OVER (PARTITION BY p.product_id ORDER BY 
                      SUM(oi.quantity * oi.list_price * (1 - p.discount_percent / 100.0)) DESC) AS revenue_rank
    FROM production.promotion p
    INNER JOIN sales.order_item oi ON p.product_id = oi.product_id
    INNER JOIN sales.[order] o ON oi.order_id = o.order_id
    WHERE o.order_date BETWEEN p.effective_start_date AND p.effective_end_date
    GROUP BY p.product_id, p.effective_start_date, p.effective_end_date, p.discount_percent
) AS RankedPromotions
WHERE revenue_rank <= 5
ORDER BY product_id, revenue_rank;

-- Calculates promotion performance per distinct promotion period
-- Uses a subquery to determine the end date of each promotion as the start date of the next promotion
-- Does not use the effective_end_date column
SELECT *
FROM (
    SELECT
        p.product_id,
        p.effective_start_date AS start_date,
        ISNULL(
            (SELECT MIN(p2.effective_start_date) 
             FROM production.promotion p2
             WHERE p2.product_id = p.product_id
               AND p2.effective_start_date > p.effective_start_date), 
            '9999-12-31'
        ) AS end_date,
        p.discount_percent,
        SUM(oi.quantity) AS total_sold_quantity,
        SUM(oi.quantity * oi.list_price) AS total_original_revenue,
        SUM(oi.quantity * oi.list_price * (1 - p.discount_percent / 100.0)) AS total_discounted_revenue,
        RANK() OVER (PARTITION BY p.product_id ORDER BY 
                      SUM(oi.quantity * oi.list_price * (1 - p.discount_percent / 100.0)) DESC) AS revenue_rank
    FROM production.promotion p
    INNER JOIN sales.order_item oi ON p.product_id = oi.product_id
    INNER JOIN sales.[order] o ON oi.order_id = o.order_id
            AND o.order_date BETWEEN p.effective_start_date AND ISNULL(
            (SELECT MIN(p2.effective_start_date) 
             FROM production.promotion p2
             WHERE p2.product_id = p.product_id
               AND p2.effective_start_date > p.effective_start_date), 
            '9999-12-31'
        )
    GROUP BY p.product_id, p.effective_start_date, p.effective_end_date, p.discount_percent
) AS RankedPromotions
WHERE revenue_rank <= 5
ORDER BY product_id, revenue_rank;

ROLLBACK TRANSACTION;

-----------------------------------------------------------------------------------
-- #2  A temporal table implementation example
-----------------------------------------------------------------------------------

-- Creates a temporal promotion table
CREATE TABLE production.promotion_temporal(
	product_id				VARCHAR(7)								NOT NULL,
	effective_start_date	DATETIME2 GENERATED ALWAYS AS ROW START	NOT NULL,
	effective_end_date		DATETIME2 GENERATED ALWAYS AS ROW END	NOT NULL,
	discount_percent		REAL									NOT NULL,
	PERIOD FOR SYSTEM_TIME (effective_start_date, effective_end_date),
  	CONSTRAINT pk_promotion_temporal PRIMARY KEY (product_id),
	CONSTRAINT fk_promotion_temporal_product FOREIGN KEY (product_id) 
		REFERENCES production.product (product_id) 
		ON DELETE CASCADE 
		ON UPDATE CASCADE,
	CONSTRAINT check_discount_is_between_0_and_100
		CHECK (discount_percent >= 0 AND discount_percent <= 100)
) 
WITH
(
	SYSTEM_VERSIONING = ON
	(
		HISTORY_TABLE = production.promotion_temporal_history,
		HISTORY_RETENTION_PERIOD = 12 MONTHS
	)
);
GO

--
-- Adds two products with discounts
--
INSERT INTO production.promotion_temporal (product_id, discount_percent)
	VALUES ('PRD0001', 5)

INSERT INTO production.promotion_temporal (product_id, discount_percent)
	VALUES ('PRD0002', 5)


--
-- Updates discounts
--
DECLARE @Counter INT = 1;
DECLARE @MaxUpdates INT = 5; -- Total number of updates to apply
DECLARE @ProductId1 VARCHAR(7) = 'PRD0001';
DECLARE @ProductId2 VARCHAR(7) = 'PRD0002';

-- Loop to apply updates for product PRD0001
WHILE @Counter <= @MaxUpdates
BEGIN
    UPDATE production.promotion_temporal
    SET discount_percent = @Counter * 5 -- Example discount increment
    WHERE product_id = @ProductId1;
    
    SET @Counter = @Counter + 1;
    WAITFOR DELAY '00:00:01'; -- Delay between updates for demonstration
END

-- Reset counter for the next product
SET @Counter = 1;

-- Loop to apply updates for product PRD0002
WHILE @Counter <= @MaxUpdates
BEGIN
    UPDATE production.promotion_temporal
    SET discount_percent = @Counter * 10 -- Example discount increment
    WHERE product_id = @ProductId2;
    
    SET @Counter = @Counter + 1;
    WAITFOR DELAY '00:00:01'; -- Delay between updates for demonstration
END


SELECT * FROM production.promotion_temporal;
SELECT * FROM production.promotion_temporal_history;


-- Retrieves data for PRD0001
SELECT * 
FROM production.promotion_temporal
    FOR SYSTEM_TIME BETWEEN 
		'2024-08-12 01:29:02.6645510' AND 
		'2024-08-12 01:29:03.6744266'
WHERE product_id = 'PRD0001' ORDER BY effective_start_date;
GO

SELECT * 
FROM production.promotion_temporal
    FOR SYSTEM_TIME AS OF '2024-08-12 01:29:02.6645510' 
WHERE product_id = 'PRD0001' ORDER BY effective_start_date;
GO


-- Recovering a deleted record
DELETE FROM production.promotion_temporal 
WHERE product_id = 'PRD0001';
GO

INSERT INTO production.promotion_temporal(
	product_id, 
	discount_percent
) 
SELECT 
	product_id, 
	discount_percent
FROM production.promotion_temporal  
   FOR SYSTEM_TIME AS OF '2024-08-12 01:29:04.6868799' 
WHERE product_id = 'PRD0001' 
GO

-- Full history for PRD0002
SELECT *
FROM production.promotion_temporal
    FOR SYSTEM_TIME ALL
WHERE product_id = 'PRD0002'
ORDER BY effective_start_date;

-- Audit log analysis for PRD0002
SELECT product_id,
       effective_start_date,
       effective_end_date,
       discount_percent,
       LAG(discount_percent) OVER (PARTITION BY product_id ORDER BY effective_start_date) AS previous_discount_percent
FROM production.promotion_temporal
    FOR SYSTEM_TIME ALL
WHERE product_id = 'PRD0001'
ORDER BY effective_start_date;



-- Drops temporal and history tables
ALTER TABLE production.promotion_temporal  SET (SYSTEM_VERSIONING = OFF)
DROP TABLE production.promotion_temporal;
DROP TABLE production.promotion_temporal_history;



--------------------------------------------------------
-- Updates the schema migration history table
--------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (13, 'History table (effective start, end dates)');





