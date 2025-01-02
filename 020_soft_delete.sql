-----------------------------------------------------------------------------------
-- Script 020                                                                 
--       
-- SOFT DELETE                  
--                                                                               
-----------------------------------------------------------------------------------
USE OnlineStore;
GO


-- Adds a deleted_at flag to mark deleted customers
ALTER TABLE person.customer ADD deleted_at DATETIME;
GO


-- Captures the deleted rows and instead of deleting them 
-- sets the deleted_at field to the current date and time
CREATE OR ALTER TRIGGER person.on_instead_customer_deleted ON person.customer 
	INSTEAD OF DELETE
AS
 BEGIN
	SET NOCOUNT ON;
	UPDATE person.customer 
		SET deleted_at = GETDATE()
	FROM DELETED 
	WHERE person.customer.customer_id = DELETED.customer_id
 END  
GO


-- Adds a filtered index on deleted_at column
CREATE NONCLUSTERED INDEX ix_customer_deleted_at_filtered
    ON person.customer (deleted_at)
    WHERE deleted_at IS NOT NULL;
GO


-- Retrieves deleted customers
SELECT *
FROM person.customer   
WHERE deleted_at IS NOT NULL;



-- Gets basic ix_customer_deleted_at_filtered index information
EXEC dbo.get_index_basic_page_info 'ix_customer_deleted_at_filtered';


/* 
	Delete any single customer prior to running the below stored procedure:

	EXEC dbo.get_index_leaf_page_content 'ix_customer_deleted_at_filtered' 
*/


-- After the refactoring, the queries involving customers
-- may need to be changed to include the deleted_at field
SELECT *
FROM person.customer   
WHERE person.customer.state = 'NY'
	AND deleted_at is NULL;


-- Calculates the total amount spent by each customer on each product
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
	WHERE c.deleted_at IS NULL
GROUP BY c.customer_id, p.product_id


-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (20, 'Soft delete');