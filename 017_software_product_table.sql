-----------------------------------------------------------------------------------
-- Script 017                                                                 
--       
-- SOFTWARE PRODUCT TABLE                   
--                                                                               
-----------------------------------------------------------------------------------
USE OnlineStore;
GO


-- Creates a software_product table
CREATE TABLE production.software_product (
	software_product_id		VARCHAR(7)		NOT NULL,
	compatible_os			VARCHAR (50)	NULL,
	required_disk_space		FLOAT			NULL,
	required_ram			FLOAT			NULL,
	CONSTRAINT pk_software_product PRIMARY KEY (software_product_id),
	CONSTRAINT fk_software_product_product FOREIGN KEY (software_product_id) 
		REFERENCES production.product (product_id) 
		ON DELETE CASCADE 
		ON UPDATE CASCADE
);
GO


-- Populates the software_product table with data
INSERT INTO production.software_product (
	software_product_id, 
	compatible_os, 
	required_disk_space,
	required_ram
)
SELECT 
	product_id, 
	compatible_os, 
	required_disk_space, 
	required_ram
FROM production.product 
WHERE product_category_id IN 
	(
		SELECT product_category_id 
		FROM production.product_category 
		WHERE product_category.path LIKE 
			(
				SELECT CONCAT(
				(
					SELECT product_category_id 
					FROM production.product_category 
					WHERE name = 'Software Products'
				),'%')
			)
	)
GO


-- Drops columns which were moved to the software table
ALTER TABLE production.product DROP COLUMN compatible_os;
ALTER TABLE production.product DROP COLUMN required_disk_space;
ALTER TABLE production.product DROP COLUMN required_ram;
GO


-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (17, 'Software product table');