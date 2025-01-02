-----------------------------------------------------------------------------------
-- Script 001                                                                 
--                                                                               
-- PRIMARY KEY                               
--                                                                               
-----------------------------------------------------------------------------------
USE OnlineStore;
GO

-- Adds a product_number column to the order_item table and copies the data
ALTER TABLE sales.order_item ADD product_number VARCHAR(7); 
GO

UPDATE sales.order_item 
	SET product_number = p.product_number
FROM sales.order_item oi
JOIN production.product p on oi.product_id = p.product_id

ALTER TABLE sales.order_item DROP CONSTRAINT fk_order_item_product; 
GO


-- Adds a product_number column to the review table and copies the data
ALTER TABLE production.review ADD product_number VARCHAR(7); 
GO

UPDATE production.review
	SET product_number = p.product_number
FROM production.review pr
	JOIN production.product p on pr.product_id = p.product_id

ALTER TABLE production.review DROP CONSTRAINT fk_review_product; 
GO

-- Adds a product_number column to the review_image table and copies the data
ALTER TABLE production.review_image ADD product_number VARCHAR(7); 
GO

UPDATE production.review_image
	SET product_number = p.product_number
FROM production.review_image ri
JOIN production.product p on ri.product_id = p.product_id

ALTER TABLE production.review_image DROP CONSTRAINT fk_review_image_product; 
GO

-- Redefines primary key for the product table
ALTER TABLE production.product DROP CONSTRAINT pk_product; 

ALTER TABLE production.product 
	ADD CONSTRAINT pk_product
	PRIMARY KEY (product_number);
GO

-- Adds foreign key constraints to the order_item, review and review_image tables-
ALTER TABLE sales.order_item 
	ADD CONSTRAINT fk_order_item_product 
	FOREIGN KEY (product_number)
    REFERENCES production.product(product_number);

ALTER TABLE production.review 
	ADD CONSTRAINT fk_review_product 
	FOREIGN KEY (product_number)
    REFERENCES production.product(product_number);

ALTER TABLE production.review_image
	ADD CONSTRAINT fk_review_image_product 
	FOREIGN KEY (product_number)
    REFERENCES production.product(product_number);

GO


-- Redefines the primary key for the review table
ALTER TABLE production.review ALTER COLUMN product_number VARCHAR(7) NOT NULL;
ALTER TABLE production.review DROP CONSTRAINT pk_review; 
ALTER TABLE production.review 
	ADD CONSTRAINT pk_review 
	PRIMARY KEY (product_number, author_id);
GO


-- Redefines the primary key for the review_image table
ALTER TABLE production.review_image ALTER COLUMN product_number VARCHAR(7) NOT NULL;
ALTER TABLE production.review_image DROP CONSTRAINT pk_review_image; 
ALTER TABLE production.review_image 
	ADD CONSTRAINT pk_review_image
	PRIMARY KEY (product_number, author_id, review_image_id);
GO


-- Changes the product_number column type so that NULLs are not allowed
ALTER TABLE sales.order_item ALTER COLUMN product_number VARCHAR(7) NOT NULL;


-- Drops redundant product_id columns from the product, order_item, review and review_image tables
ALTER TABLE production.product DROP COLUMN product_id; 
ALTER TABLE sales.order_item DROP COLUMN product_id; 
ALTER TABLE production.review DROP COLUMN product_id; 
ALTER TABLE production.review_image DROP COLUMN product_id; 
GO


-- Changes the product_number column back to product_id
EXEC sp_rename 'production.product.product_number', 'product_id', 'COLUMN';
EXEC sp_rename 'sales.order_item.product_number', 'product_id', 'COLUMN';
EXEC sp_rename 'production.review.product_number', 'product_id', 'COLUMN';
EXEC sp_rename 'production.review_image.product_number', 'product_id', 'COLUMN';

CREATE NONCLUSTERED INDEX ix_order_item_product_id ON sales.order_item (product_id);
CREATE NONCLUSTERED INDEX ix_review_product_id ON production.review  (product_id);
CREATE NONCLUSTERED INDEX ix_review_image_product_id ON production.review_image  (product_id);


-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (1, 'Primary key');

 


