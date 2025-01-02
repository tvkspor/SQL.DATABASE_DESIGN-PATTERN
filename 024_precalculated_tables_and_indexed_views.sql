-----------------------------------------------------------------------------------
-- Script 024                                                                 
--       
-- PRECALCULATED TABLES AND INDEXED VIEWS
--
--  #1  Numbers Table
--  #2  Calendar Table
--  #3  Indexed View                                                                
-----------------------------------------------------------------------------------
USE OnlineStore;
GO

-----------------------------------------------------------------------------------
-- #1  Numbers Table
-----------------------------------------------------------------------------------

-- Creates a number table to store a list of integers
CREATE TABLE dbo.number (
	id INT NOT NULL
	CONSTRAINT pk_number PRIMARY KEY (id)
);
GO
 
WITH number_cte(id)
AS
(
	 SELECT 1

	 UNION ALL

	 SELECT id + 1
	 FROM number_cte
	 WHERE id < 100000
)
INSERT INTO dbo.number(
	id
)
SELECT id
FROM number_cte
OPTION (MAXRECURSION 0);
GO


-- Finds dates where there were no orders
DECLARE @start_date DATETIME = '20200101',
		@end_date DATETIME = '20231231';

SELECT c.Date
FROM
(
    -- Generatse date sequence and casts the result to DATE
    SELECT CAST(DATEADD(DAY, id - 1, @start_date) AS DATE) AS Date
    FROM dbo.number 
    WHERE id <= DATEDIFF(DAY, @start_date, @end_date) + 1
) c
LEFT OUTER JOIN
(
    SELECT * 
    FROM sales.[order] o
    WHERE o.order_date >= @start_date 
      AND o.order_date <= @end_date + 1
) o ON CONVERT(DATE, o.order_date) = c.Date
WHERE o.order_date IS NULL;


-- Finds gaps in vendor ids
BEGIN TRANSACTION;  
	ALTER TABLE production.product DROP CONSTRAINT fk_product_vendor;

	DELETE FROM production.vendor
	WHERE vendor_id = 42

	SELECT id AS 'vendor_id'
	FROM dbo.number n
	LEFT OUTER JOIN
	(
		SELECT 
			v.vendor_id
		FROM production.vendor v
	) b ON n.id = b.vendor_id
	WHERE n.id <= (SELECT MAX(vendor_id) FROM production.vendor) 
	  AND b.vendor_id IS NULL;

ROLLBACK TRANSACTION; 
GO



-----------------------------------------------------------------------------------
-- #2  Calendar Table
-----------------------------------------------------------------------------------

-- Create a calendar table to store precalculated date-related data
CREATE TABLE dbo.calendar(
	date_value				DATE		NOT NULL,
	next_date				DATE		NOT NULL,
	[year]					SMALLINT	NOT NULL,
	[quarter]				TINYINT		NOT NULL,
	[month]					TINYINT		NOT NULL,
	[week]					TINYINT		NOT NULL,
	day_of_week				SMALLINT	NOT NULL,
	day_of_month			SMALLINT	NOT NULL,
	day_of_year				SMALLINT	NOT NULL,
	month_short_name		VARCHAR(3)	NOT NULL,
	month_long_name			VARCHAR(15)	NOT NULL,
	day_of_week_short_name	VARCHAR(3)	NOT NULL,
	day_of_week_long_name	VARCHAR(15)	NOT NULL,
	is_weekend				BIT			NOT NULL,
	is_public_holiday		BIT			NOT NULL,
	is_company_holiday		BIT			NOT NULL,
	week_of_month			TINYINT     NOT NULL,
    last_day_of_month		DATE        NOT NULL,
    is_pay_day				BIT         NOT NULL,
	CONSTRAINT pk_calendar_id PRIMARY KEY (date_value)
);
GO

-- Populates the calendar table with data
DECLARE @start_date DATE = '20200101',
		@end_date DATE = '20241231'

;WITH cte_calendar(date_value) AS 
(
    SELECT @start_date
    UNION ALL
    SELECT DATEADD(d, 1, date_value)
    FROM cte_calendar
    WHERE date_value < @end_date
)
INSERT INTO dbo.calendar(
    date_value,
    next_date, 
    [year],
    [quarter],
    [month],
    [week],
    day_of_week,
    day_of_month, 
    day_of_year,
    month_short_name, 
    month_long_name, 
    day_of_week_short_name,
    day_of_week_long_name,
    is_weekend,
    is_public_holiday,
    is_company_holiday,
    week_of_month,
    last_day_of_month,
    is_pay_day
)
SELECT 
	date_value, 
	DATEADD(d, 1, date_value)		AS 'next_day_date',
	YEAR(date_value)				AS 'year',
	DATEPART(QUARTER, date_value)	AS 'quarter',
	MONTH(date_value)				AS 'month',
	DATEPART(WEEK, date_value)		AS 'week',
	DATEPART(WEEKDAY, date_value)	AS 'day_of_week',
	DAY(date_value)					AS 'day_of_month',
	DATEPART(DAYOFYEAR, date_value)	AS 'day_of_year',
	FORMAT(date_value, 'MMM')		AS 'month_short_name',
	DATENAME(MONTH, date_value)		AS 'month_long_name',
	FORMAT(date_value, 'ddd')		AS 'day_of_week_short_name',
	DATENAME(WEEKDAY, date_value)	AS 'day_of_week_long_name',
	(
		CASE 
			WHEN DATEPART(WEEKDAY, date_value) IN 
				(
					CASE @@DATEFIRST 
						WHEN 1 THEN 6 
						WHEN 7 THEN 1 
					END,
					7
				) 
			THEN 1 
			ELSE 0 
		END
	) AS 'is_weekend',
	(  
		CASE date_value
			WHEN DATEFROMPARTS(YEAR(date_value), 12, 25) THEN 1 -- Christmas Day
			WHEN DATEFROMPARTS(YEAR(date_value), 1,  1) THEN 1  -- New Year's Day
		ELSE 0 END
	) AS 'is_public_holiday',
	(  
		CASE date_value
			WHEN DATEFROMPARTS(YEAR(date_value), 3,  1) THEN 1  -- Company holiday
			WHEN DATEFROMPARTS(YEAR(date_value), 3,  2) THEN 1  -- Company holiday
			WHEN DATEFROMPARTS(YEAR(date_value), 3,  3) THEN 1  -- Company holiday
			WHEN DATEFROMPARTS(YEAR(date_value), 3,  4) THEN 1  -- Company holiday
			WHEN DATEFROMPARTS(YEAR(date_value), 3,  5) THEN 1  -- Company holiday
			WHEN DATEFROMPARTS(YEAR(date_value), 3,  6) THEN 1  -- Company holiday
			WHEN DATEFROMPARTS(YEAR(date_value), 3,  7) THEN 1  -- Company holiday
		ELSE 0 END
	) AS 'is_company_holiday',
    DATEPART(WEEK, date_value) - DATEPART(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, date_value), 0)) + 1 AS week_of_month,
    EOMONTH(date_value) AS last_day_of_month,
    CASE 
        WHEN DAY(date_value) = 25 THEN 1
        ELSE 0 
    END AS 'is_pay_day'
FROM cte_calendar
OPTION (MAXRECURSION 0)
GO


-- Calculation of number of working days using the calendars
DECLARE @start_date DATE = '20240101';
DECLARE @end_date DATE = '20241231';
SELECT COUNT(*) 
FROM dbo.calendar AS c
WHERE date_value >= @start_date
  AND date_value <= @end_date
  AND is_weekend = 0
  AND is_public_holiday = 0
  AND is_company_holiday = 0


-- Gets all paydays within the date range
DECLARE @start_date_pay_day DATE = '20240101';
DECLARE @end_date_pay_day DATE = '20241231';
SELECT c.date_value AS payday
FROM dbo.calendar c
WHERE c.is_pay_day = 1
  AND c.date_value BETWEEN @start_date_pay_day AND @end_date_pay_day;


-- Determines next shipment date based on order time and holidays
DECLARE @payment_received_status_id INT;
SELECT @payment_received_status_id = order_status_type_id 
FROM sales.order_status_type 
WHERE name = 'PAYMENT_RECEIVED';

SELECT 
    o.order_id,
    o.order_date,
    shipment_date.date_value AS next_shipment_date
FROM sales.[order] o
CROSS APPLY (
    SELECT TOP 1 c.date_value
    FROM dbo.calendar c
    WHERE c.date_value > CASE 
                            -- If the order was received after 2 PM, add 1 more day
                            WHEN CAST(o.order_date AS TIME) > '14:00:00' 
                            THEN DATEADD(DAY, 1, o.order_date)  
                            ELSE o.order_date 
                         END
      AND c.is_public_holiday = 0  -- Not a public holiday
      AND c.is_company_holiday = 0  -- Not a company holiday
    ORDER BY c.date_value
) AS shipment_date
WHERE o.order_status_type_id = @payment_received_status_id
AND MONTH(o.order_date) = 3 
    AND YEAR(o.order_date) = 2023
ORDER BY o.order_date;



-----------------------------------------------------------------------------------
-- #3  Indexed View  
-----------------------------------------------------------------------------------

SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, 
	ANSI_WARNINGS, 
	CONCAT_NULL_YIELDS_NULL, 
	ARITHABORT,
	QUOTED_IDENTIFIER, 
	ANSI_NULLS ON;
GO

CREATE VIEW sales.customer_total_spent_per_product_view WITH SCHEMABINDING
AS
	SELECT 
		c.customer_id,
		p.product_id,
		SUM(
			oi.quantity * 
			oi.list_price * 
			(1.00 - oi.discount_percent/100)
		) AS 'total_spent',
		COUNT_BIG(*) AS 'count'
	FROM person.customer c
		JOIN sales.[order] o ON c.customer_id = o.customer_id
		JOIN sales.order_item oi ON o.order_id = oi.order_id
		JOIN production.product p ON oi.product_id  = p.product_id
	GROUP BY c.customer_id, p.product_id;
GO


-- Creates a clustered index on the indexed view
CREATE UNIQUE CLUSTERED INDEX ix_customer_total_spent_per_product_view_customer_id_product_id 
	ON sales.customer_total_spent_per_product_view(customer_id, product_id);
GO

-- Creates a normal view
CREATE VIEW sales.customer_total_spent_per_product_view_NORMAL 
AS
	SELECT 
		c.customer_id,
		p.product_id,
		SUM(
			oi.quantity * 
			oi.list_price * 
			(1.00 - oi.discount_percent/100)
		) AS 'total_spent',
		COUNT_BIG(*) AS 'count'
	FROM person.customer c
		JOIN sales.[order] o ON c.customer_id = o.customer_id
		JOIN sales.order_item oi ON o.order_id = oi.order_id
		JOIN production.product p ON oi.product_id  = p.product_id
	GROUP BY c.customer_id, p.product_id;
GO


--
-- Query performance comparison
-- 

-- Query using the regular view (no precomputed data)
SELECT * FROM sales.customer_total_spent_per_product_view_NORMAL;
-- Query using the indexed view
SELECT * FROM sales.customer_total_spent_per_product_view WITH (NOEXPAND); -- Forces the query optimizer to use the indexed view


-- Drops the indexed view's clustered index
ALTER INDEX ALL ON sales.customer_total_spent_per_product_view DISABLE;

--
-- Update performance comparison
--
BEGIN TRAN;
SET STATISTICS IO ON
DECLARE @new_order_id INT = (SELECT MAX(order_id) FROM sales.[order]) + 1;
DECLARE @product_id VARCHAR(7) = 'PRD0019';
DECLARE @price FLOAT = 650.0;

SET IDENTITY_INSERT sales.[order] ON;
INSERT INTO sales.[order](order_id, customer_id, order_date, order_status_type_id) 
	VALUES
		(@new_order_id,     1, GETDATE(), 1),
		(@new_order_id + 1, 2, GETDATE(), 1),
		(@new_order_id + 2, 3, GETDATE(), 1);
SET IDENTITY_INSERT sales.[order] OFF;

INSERT INTO sales.order_item(order_id, item_id, product_id, list_price, quantity) 
	VALUES 
		(@new_order_id,     1, @product_id, @price, 1),
		(@new_order_id,     2, @product_id, @price, 2),
		(@new_order_id,     3, @product_id, @price, 1),
		(@new_order_id,     4, @product_id, @price, 2),
		(@new_order_id + 1, 1, @product_id, @price, 3),
		(@new_order_id + 1, 2, @product_id, @price, 2),
		(@new_order_id + 1, 3, @product_id, @price, 1),
		(@new_order_id + 1, 4, @product_id, @price, 2),
		(@new_order_id + 2, 1, @product_id, @price, 1),
		(@new_order_id + 2, 2, @product_id, @price, 1),
		(@new_order_id + 2, 3, @product_id, @price, 1),
		(@new_order_id + 2, 4, @product_id, @price, 1);
GO
ROLLBACK;


-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (24, 'Precalculated tables and indexed views');
