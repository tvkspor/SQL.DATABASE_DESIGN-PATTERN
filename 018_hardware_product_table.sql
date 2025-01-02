-----------------------------------------------------------------------------------
-- Script 018                                                                 
--       
-- HARDWARE PRODUCT TABLE                   
--                                                                               
-----------------------------------------------------------------------------------
USE OnlineStore;
GO


-- Creates a hardware_product table
CREATE TABLE production.hardware_product (
	hardware_product_id		VARCHAR(7)	NOT NULL,
	weight					FLOAT		NULL,
	height					FLOAT		NULL,
	width					FLOAT		NULL,
	length					FLOAT		NULL,
	CONSTRAINT pk_hardware_product PRIMARY KEY (hardware_product_id),
	CONSTRAINT fk_hardware_product_product FOREIGN KEY (hardware_product_id) 
		REFERENCES production.product (product_id) 
		ON DELETE CASCADE 
		ON UPDATE CASCADE
);
GO


-- Populates the hardware_product table with data
INSERT INTO production.hardware_product (
	hardware_product_id, 
	weight, 
	height, 
	width, 
	length
)
SELECT 
	product_id, 
	weight, 
	height, 
	width, 
	length
FROM production.product p
JOIN production.product_category pc 
    ON p.product_category_id = pc.product_category_id
WHERE pc.path NOT LIKE CONCAT(
        (
            SELECT pc2.path 
            FROM production.product_category pc2 
            WHERE pc2.name = 'Software Products'
        ), '%')
GO


-- Drops columns which were moved to the hardware product table
ALTER TABLE production.product DROP COLUMN weight;
ALTER TABLE production.product DROP COLUMN height;
ALTER TABLE production.product DROP COLUMN width;
ALTER TABLE production.product DROP COLUMN length;
GO


CREATE OR ALTER VIEW production.product_view
AS
	SELECT 
		product_id,
		name,
		product_category_id,
		list_price,
		vendor_id,
		compatible_os,
		required_disk_space,
		required_ram,
		weight,
		height,
		width,
		length
	FROM production.product p
	LEFT JOIN production.software_product sp ON p.product_id = sp.software_product_id
	LEFT JOIN production.hardware_product hp ON p.product_id = hp.hardware_product_id
GO

SELECT * FROM production.product_view
WHERE product_id = 'PRD0081'

-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (18, 'Hardware product table');

