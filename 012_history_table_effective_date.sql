-----------------------------------------------------------------------------------
-- Script 012                                                                 
--       
-- HISTORY TABLE (EFFECTIVE DATE)                    
--   
-- #1  order_status_history table creation
-- #2  Event sourcing
--                                                                              
-----------------------------------------------------------------------------------
USE OnlineStore;
GO


-----------------------------------------------------------------------------------
-- #1  order_status_history table creation
-----------------------------------------------------------------------------------

-- Creates order_status_history table
CREATE TABLE sales.order_status_history (
	order_status_history_id INT			NOT NULL	IDENTITY (1, 1),
	order_id				INT			NOT NULL,
	order_status_type_id	TINYINT		NOT NULL,
	order_date				DATETIME	NOT NULL,
	CONSTRAINT pk_order_status_history PRIMARY KEY (order_status_history_id),
	CONSTRAINT fk_order_status_history_order FOREIGN KEY (order_id)
		REFERENCES sales.[order] (order_id) 
		ON DELETE CASCADE,
	CONSTRAINT fk_order_status_history_order_status_type FOREIGN KEY (order_status_type_id) 
		REFERENCES sales.order_status_type (order_status_type_id) 
		ON DELETE NO ACTION,
	INDEX ix_order_status_history_order_id (order_id)
);
GO


-- Adds trigger to fire each time data is inserted or updated in the order table
-- The trigger saves the data into the order_status_history table
CREATE TRIGGER sales.on_after_order_inserted_updated ON sales.[order] 
  AFTER INSERT, UPDATE
AS 
BEGIN
	SET NOCOUNT ON;

	INSERT INTO sales.order_status_history(order_id, order_status_type_id, order_date)
	SELECT 
		order_id, 
		order_status_type_id, 
		order_date
	FROM 
		INSERTED;
END
GO


-- Seeds the order and order_item tables with sample data
SET IDENTITY_INSERT sales.[order] ON;
INSERT INTO sales.[order](order_id, customer_id, order_date, order_status_type_id) 
	VALUES
	(100001,1,'20231212 00:00:00.000',1),
	(100002,2,'20231217 00:00:00.000',1),
	(100003,3,'20231221 00:10:00.000',1);
SET IDENTITY_INSERT sales.[order] OFF;
GO
INSERT INTO sales.order_item(order_id, item_id, product_id, quantity) 
	VALUES
		(100001,1,'PRD0019',1),
		(100001,2,'PRD0019',2),
		(100001,3,'PRD0019',1),
		(100001,4,'PRD0019',2),
		(100002,1,'PRD0019',3),
		(100002,2,'PRD0019',2),
		(100002,3,'PRD0019',1),
		(100002,4,'PRD0019',2),
		(100003,1,'PRD0019',1),
		(100003,2,'PRD0019',1),
		(100003,3,'PRD0019',1),
		(100003,4,'PRD0019',1);
UPDATE sales.[order] SET order_status_type_id = 2, order_date = '2023-12-13 00:00:00.000' FROM sales.[order] o WHERE o.order_id = 100001
UPDATE sales.[order] SET order_status_type_id = 3, order_date = '2023-12-14 00:00:00.000' FROM sales.[order] o WHERE o.order_id = 100001
UPDATE sales.[order] SET order_status_type_id = 4, order_date = '2023-12-15 00:00:00.000' FROM sales.[order] o WHERE o.order_id = 100001
UPDATE sales.[order] SET order_status_type_id = 2, order_date = '2023-12-17 00:10:00.000' FROM sales.[order] o WHERE o.order_id = 100002
UPDATE sales.[order] SET order_status_type_id = 3, order_date = '2023-12-18 12:15:00.000' FROM sales.[order] o WHERE o.order_id = 100002
UPDATE sales.[order] SET order_status_type_id = 4, order_date = '2023-12-19 16:54:00.000' FROM sales.[order] o WHERE o.order_id = 100002
UPDATE sales.[order] SET order_status_type_id = 2, order_date = '2023-12-21 03:27:00.000' FROM sales.[order] o WHERE o.order_id = 100003
UPDATE sales.[order] SET order_status_type_id = 3, order_date = '2023-12-22 10:56:00.000' FROM sales.[order] o WHERE o.order_id = 100003
UPDATE sales.[order] SET order_status_type_id = 4, order_date = '2023-12-24 14:35:00.000' FROM sales.[order] o WHERE o.order_id = 100003
GO

-- To get the average time between payment reception and shippment the following query can be used
SELECT 
	AVG(datediff(HOUR, a.order_date, b.order_date)) 
FROM sales.order_status_history a
	JOIN sales.order_status_history b ON a.order_id = b.order_id
	AND a.order_status_type_id = 
	(
		SELECT order_status_type_id 
		FROM sales.order_status_type 
		WHERE name = 'PAYMENT_RECEIVED'
	)
	AND b.order_status_type_id = 
	(
		SELECT order_status_type_id 
		FROM sales.order_status_type 
		WHERE name = 'SHIPPED'
	)


-----------------------------------------------------------------------------------
-- #2  Event sourcing
-----------------------------------------------------------------------------------

-- Creates a table to store customer account charge history
CREATE TABLE customer_point_charge_event_history (
    event_id INT PRIMARY KEY IDENTITY,
    event_type VARCHAR(50) NOT NULL CHECK (event_type IN ('recharge', 'withdraw')),
    event_data NVARCHAR(MAX) NOT NULL,
    event_timestamp DATETIME NOT NULL
);

-- Creates a table to store customer points
CREATE TABLE customer_point (
    customer_id INT PRIMARY KEY,
    points INT
);
GO

-- A stored procedure that parses the point charge events
-- and applies them to customer_point table
CREATE OR ALTER PROCEDURE update_customer_points
	@event_type NVARCHAR(20),
    @event_data NVARCHAR(MAX)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @customer_id INT, 
			@points INT;
 
    SET @customer_id = CAST(JSON_VALUE(@event_data, '$.customer_id') AS INT);
    SET @points = CAST(JSON_VALUE(@event_data, '$.points') AS INT);

	IF EXISTS (SELECT * FROM customer_point WHERE customer_id = @customer_id)
		BEGIN
			IF @event_type = 'recharge'
				BEGIN
 					UPDATE customer_point
					SET points = points + @points
					WHERE customer_id = @customer_id;

					PRINT 'customer_id: ' + CAST(@customer_id AS VARCHAR(10)) + ' account recharged with ' + CAST(@points AS VARCHAR(10));
				END
			ELSE 
				BEGIN
  					UPDATE customer_point
					SET points = points - @points
					WHERE customer_id = @customer_id;
					PRINT 'customer_id: ' + CAST(@customer_id AS VARCHAR(10)) + ' account charged with ' + CAST(@points AS VARCHAR(10));
				END
		END
	ELSE
		BEGIN
			INSERT INTO customer_point (customer_id, points)
			VALUES (@customer_id, @points);
		END;
END;
GO

-- Simulates 8 events
INSERT INTO customer_point_charge_event_history (event_type, event_data, event_timestamp)
	VALUES ('recharge', '{ "customer_id": 1,  "points": 100}', SYSDATETIME());
INSERT INTO customer_point_charge_event_history (event_type, event_data, event_timestamp)
	VALUES ('recharge', '{ "customer_id": 1,  "points":  50}', SYSDATETIME());
INSERT INTO customer_point_charge_event_history (event_type, event_data, event_timestamp)
	VALUES ('withdraw', '{ "customer_id": 2,  "points":  50}', SYSDATETIME());
INSERT INTO customer_point_charge_event_history (event_type, event_data, event_timestamp)
	VALUES ('withdraw', '{ "customer_id": 1,  "points":  50}', SYSDATETIME());
INSERT INTO customer_point_charge_event_history (event_type, event_data, event_timestamp)
	VALUES ('recharge', '{ "customer_id": 2,  "points":  50}', SYSDATETIME());
INSERT INTO customer_point_charge_event_history (event_type, event_data, event_timestamp)
	VALUES ('withdraw', '{ "customer_id": 3,  "points":  50}', SYSDATETIME());
INSERT INTO customer_point_charge_event_history (event_type, event_data, event_timestamp)
	VALUES ('recharge', '{ "customer_id": 1,  "points": 150}', SYSDATETIME());
INSERT INTO customer_point_charge_event_history (event_type, event_data, event_timestamp)
	VALUES ('recharge', '{ "customer_id": 2,  "points":  50}', SYSDATETIME());

 

SELECT * FROM customer_point_charge_event_history;
SELECT * FROM customer_point;


--
-- Cursor for applying events
--
DECLARE @param_1 NVARCHAR(20), 
        @param_2 NVARCHAR(MAX);
		
DECLARE rows_cursor CURSOR FOR
	SELECT 
		event_type, 
		event_data
	FROM customer_point_charge_event_history;

OPEN rows_cursor;
FETCH NEXT FROM rows_cursor INTO @param_1, @param_2;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Calls the stored procedure with the fetched parameters
    EXEC update_customer_points @param_1, @param_2;
    -- Fetchs the next row
    FETCH NEXT FROM rows_cursor INTO @param_1, @param_2;
END;

CLOSE rows_cursor;
DEALLOCATE rows_cursor;

-- Checks customer points after applying events
SELECT * FROM customer_point;
-- DELETE FROM customer_point;


-- Clean up
DROP TABLE IF EXISTS customer_point_charge_event_history;
DROP TABLE IF EXISTS customer_point;
DROP PROCEDURE IF EXISTS update_customer_points;



-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (12, 'History table (effective date)');