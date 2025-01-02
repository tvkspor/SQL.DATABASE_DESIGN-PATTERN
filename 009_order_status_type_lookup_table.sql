-----------------------------------------------------------------------------------
-- Script 009                                                                 
--       
-- ORDER STATUS TYPE LOOKUP TABLE                      
--                                                                               
-----------------------------------------------------------------------------------
USE OnlineStore;
GO

-- Creates order_status_type lookup table
CREATE TABLE sales.order_status_type (
	order_status_type_id	TINYINT	IDENTITY (1, 1),
	name					VARCHAR(30)
	CONSTRAINT pk_order_status_type PRIMARY KEY (order_status_type_id)
);
GO


-- Populates order_status_type table with valid values
INSERT INTO sales.order_status_type (name) 
VALUES
	('OPEN'),
	('PAYMENT_RECEIVED'),
	('SHIPPED'),
	('CLOSED'),
	('CANCELLED');
GO


-- Adds an order_status_type_id field to the order table
ALTER TABLE sales.[order] ADD order_status_type_id TINYINT;
GO


-- Populates order_status_type_id field with valid values 
UPDATE [order]
SET order_status_type_id = order_status_type.order_status_type_id
FROM sales.[order]
	INNER JOIN sales.order_status_type 
	ON order_status_type.name = [order].status;
GO


-- Adds a foreign key constraint to the customer table to enforce data integrity 
ALTER TABLE sales.[order] 
	WITH CHECK
	ADD CONSTRAINT fk_order_order_status_type FOREIGN KEY (order_status_type_id) 
	REFERENCES sales.order_status_type(order_status_type_id)
	ON DELETE NO ACTION 
	ON UPDATE CASCADE;
GO


-- Deletes the unneeded status column
ALTER TABLE sales.[order] DROP COLUMN status;
GO


-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (9, 'Order status type lookup table');