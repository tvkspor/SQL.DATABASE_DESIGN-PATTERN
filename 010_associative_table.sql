-----------------------------------------------------------------------------------
-- Script 010                                                                 
--       
-- ASSOCIATIVE TABLE                      
--                                                                               
-----------------------------------------------------------------------------------
USE OnlineStore;
GO


-- Creates customer_wishlist associative (many to many) table
CREATE TABLE sales.customer_wishlist(
	customer_id		INT			NOT NULL,
	product_id		VARCHAR(7)	NOT NULL,
	wishlist_name	VARCHAR(50) NOT NULL,
	added_at		DATETIME	NOT NULL,
	CONSTRAINT pk_customer_wishlist PRIMARY KEY (customer_id, product_id),
	CONSTRAINT fk_customer_wishlist_customer FOREIGN KEY (customer_id) 
		REFERENCES person.customer (customer_id) 
		ON DELETE CASCADE 
		ON UPDATE CASCADE,
	CONSTRAINT fk_customer_wishlist_product FOREIGN KEY (product_id) 
		REFERENCES production.product (product_id) 
		ON DELETE CASCADE 
		ON UPDATE CASCADE
);
GO

-- Populates the customer_wishlist table 
INSERT INTO sales.customer_wishlist (
	customer_id, 
	product_id, 
	wishlist_name, 
	added_at
)
SELECT 
	customer_id, 
	p.product_id, 
	'default', 
	GETDATE()
FROM person.customer CROSS APPLY STRING_SPLIT(wishlist, ',') c
	JOIN production.product p ON p.name = c.value
GO


-- The wishlist column is no longer needed in the customer table so it is dropped
ALTER TABLE person.customer DROP COLUMN wishlist; 
GO

-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (10, 'Associative table');