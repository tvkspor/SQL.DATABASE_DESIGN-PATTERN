-----------------------------------------------------------------------------------
-- Script 011                                                                 
--       
-- MASTER-DETAIL                      
--     
-- #1 Master-detail implementation
-- #2 Normal index vs filtered index
--                                                                              
-----------------------------------------------------------------------------------
USE OnlineStore;
GO

-----------------------------------------------------------------------------------
-- #1 Master-detail implementation
-----------------------------------------------------------------------------------
-- Creates an order_item_shipment table
CREATE TABLE sales.order_item_shipment(
	order_shipment_id		INT				NOT NULL,
	order_item_shipment_id	INT				NOT NULL,
	order_id				INT				NOT NULL,
	order_item_id			INT				NOT NULL,
	quantity				INT				NOT NULL,
	product_id				VARCHAR(7)		NOT NULL,
	shipment_price			DECIMAL (10, 2) NOT NULL,
	created_at				DATETIME		NOT NULL,
	CONSTRAINT pk_order_item_shipment PRIMARY KEY (order_shipment_id, order_item_shipment_id),
	CONSTRAINT fk_order_item_shipment_order_shipment FOREIGN KEY (order_shipment_id) 
		REFERENCES sales.order_shipment (order_shipment_id) 
		ON DELETE CASCADE,
	CONSTRAINT fk_order_item_shipment_order_item FOREIGN KEY (order_id, order_item_id) 
		REFERENCES sales.order_item (order_id, item_id) 
		ON DELETE NO ACTION,
	CONSTRAINT fk_order_item_shipment_product FOREIGN KEY (product_id) 
		REFERENCES production.product (product_id) 
		ON DELETE NO ACTION,
	CONSTRAINT chk_order_item_shipment_quantity_is_between_1_and_50 CHECK(quantity >= 1 AND quantity <= 50),
	INDEX ix_order_item_shipment_order_id_order_item_id (order_id, order_item_id)
);
GO


-- Adds is_complete column to signify whether all the order items 
-- within a given shipment has been shipped (1) or not (0)
ALTER TABLE sales.order_shipment ADD is_complete BIT 
	CONSTRAINT df_order_shipment_is_complete_0 DEFAULT(0);
GO


-- Sets status for all the shipments to complete (1)
UPDATE sales.order_shipment
	SET is_complete = 1 
GO


-- Adds a filtered index on the is_complete column
CREATE NONCLUSTERED INDEX ix_order_shipment_is_complete_filtered
    ON sales.order_shipment (is_complete)
    WHERE is_complete = 0;
GO


-----------------------------------------------------------------------------------
-- #2 Normal index vs filtered index
-----------------------------------------------------------------------------------
-- Creates a normal index on the is_complete column
CREATE NONCLUSTERED INDEX ix_order_shipment_is_complete
    ON sales.order_shipment (is_complete);
GO


-- Normal vs filtered indexes - IO cost comparison
BEGIN TRANSACTION
DECLARE @max_order_shipment INT = (SELECT MAX(order_shipment_id) FROM sales.order_shipment);

SET IDENTITY_INSERT sales.order_shipment ON;
INSERT INTO sales.order_shipment(order_shipment_id, order_id, created_at, price) 
	VALUES	(@max_order_shipment + 1, 1, '2020-06-22 16:12:59.000', 5),
			(@max_order_shipment + 2, 2, '2020-06-22 16:12:59.000', 5),
			(@max_order_shipment + 3, 3, '2020-06-22 16:12:59.000', 5);
SET IDENTITY_INSERT sales.order_shipment OFF;

SET STATISTICS IO ON;
SELECT * 
FROM sales.order_shipment WITH (INDEX(pk_order_shipment))
WHERE is_complete = 0;
SET STATISTICS IO OFF;

SET STATISTICS IO ON;
SELECT * 
FROM sales.order_shipment WITH (INDEX(ix_order_shipment_is_complete))
WHERE is_complete = 0;
SET STATISTICS IO OFF;

SET STATISTICS IO ON;
SELECT * 
FROM sales.order_shipment WITH (INDEX(ix_order_shipment_is_complete_filtered))
WHERE is_complete = 0;
SET STATISTICS IO OFF;

-- Normal index vs filtered index - structure and size comparison
EXEC dbo.get_index_basic_page_info 'ix_order_shipment_is_complete';
EXEC dbo.get_index_basic_page_info 'ix_order_shipment_is_complete_filtered';

ROLLBACK TRANSACTION

-- Drops the redundant index
DROP INDEX IF EXISTS ix_order_shipment_is_complete ON sales.order_shipment


-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (11, 'Master detail');





