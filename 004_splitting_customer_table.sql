-----------------------------------------------------------------------------------
-- Script 004                                                                 
--       
-- SPLITTING THE CUSTOMER TABLE      
--                                                                               
-----------------------------------------------------------------------------------
USE OnlineStore;
GO

-- Creates a credit_card table to store customer's credit cards' data
CREATE TABLE sales.credit_card (
	credit_card_id		VARCHAR(255)	NOT NULL,
	customer_id			INT				NOT NULL,
	expiration_date		VARCHAR(5)		NOT NULL,
	holder_name			VARCHAR(50)		NOT NULL
	CONSTRAINT pk_credit_card  PRIMARY KEY (credit_card_id),
	CONSTRAINT fk_credit_card_customer FOREIGN KEY(customer_id) 
		REFERENCES person.customer (customer_id) 
		ON DELETE CASCADE 
		ON UPDATE CASCADE,
	INDEX ix_credit_card_customer_id (customer_id)
);

-- Migrates the credit card data from the customer table to the credit_card table
INSERT INTO sales.credit_card(
	credit_card_id, 
	customer_id, 
	expiration_date, 
	holder_name
)
SELECT 
	credit_card_id, 
	customer_id, 
	expiration_date, 
	holder_name 
FROM person.customer
GO

-- Credit card data has been migrated, so it can be deleted from the customer table
ALTER TABLE person.customer DROP COLUMN credit_card_id;
ALTER TABLE person.customer DROP COLUMN expiration_date;
ALTER TABLE person.customer DROP COLUMN holder_name;
GO


-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (4, 'Splitting the customer table');