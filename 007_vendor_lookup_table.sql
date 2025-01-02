-----------------------------------------------------------------------------------
-- Script 007                                                                 
--       
-- VENDOR LOOKUP TABLE                      
--                                                                               
-----------------------------------------------------------------------------------
USE OnlineStore;
GO

-- Creates a vendor lookup table to store product vendors
CREATE TABLE production.vendor (
	vendor_id	INT IDENTITY (1, 1),
	name		VARCHAR (255) NOT NULL
	CONSTRAINT pk_vendor PRIMARY KEY (vendor_id)
);
GO

-- Populates the vendor table with data from the product table
INSERT INTO production.vendor(
	name
) 
SELECT DISTINCT 
	vendor_name 
FROM production.product;
GO

-- Adds vendor_id to the product table
ALTER TABLE production.product ADD vendor_id INT;
GO

-- Updates the product's vendor_id column with ids from the vendor table
UPDATE product
	SET vendor_id = vendor.vendor_id 
FROM production.product
	INNER JOIN production.vendor ON product.vendor_name = vendor.name
GO

-- Establishes a foreign key constraint from the product table with the vendor table
-- to enforce data integrity
ALTER TABLE production.product WITH CHECK
	ADD CONSTRAINT fk_product_vendor FOREIGN KEY (vendor_id) 
		REFERENCES production.vendor(vendor_id)
		ON DELETE NO ACTION 
		ON UPDATE CASCADE
GO

CREATE NONCLUSTERED INDEX ix_product_vendor_id ON production.product (vendor_id)
GO
 
-- The vendor_name column has been replaced with vendor_id so it is no longer needed
ALTER TABLE production.product DROP COLUMN vendor_name;
GO


-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (7, 'Vendor lookup table');