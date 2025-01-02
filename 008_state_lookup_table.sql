-----------------------------------------------------------------------------------
-- Script 008                                                                 
--       
-- STATE LOOKUP TABLE                      
--                                                                               
-----------------------------------------------------------------------------------
USE OnlineStore;
GO

-- Creates a state lookup table
CREATE TABLE person.state (
	state_id	VARCHAR(2),
	name		VARCHAR(50)
	CONSTRAINT pk_state PRIMARY KEY(state_id)
);
GO


-- Populates the state table with valid values
INSERT INTO person.state (state_id, name) 
VALUES
	('AL','ALABAMA'),
	('AK','ALASKA'),
	('AS','AMERICAN SAMOA'),
	('AZ','ARIZONA'),
	('AR','ARKANSAS'),
	('CA','CALIFORNIA'),
	('CO','COLORADO'),
	('CT','CONNECTICUT'),
	('DE','DELAWARE'),
	('DC','DISTRICT OF COLUMBIA'),
	('FL','FLORIDA'),
	('GA','GEORGIA'),
	('GU','GUAM'),
	('HI','HAWAII'),
	('ID','IDAHO'),
	('IL','ILLINOIS'),
	('IN','INDIANA'),
	('IA','IOWA'),
	('KS','KANSAS'),
	('KY','KENTUCKY'),
	('LA','LOUISIANA'),
	('ME','MAINE'),
	('MD','MARYLAND'),
	('MA','MASSACHUSETTS'),
	('MI','MICHIGAN'),
	('MN','MINNESOTA'),
	('MS','MISSISSIPPI'),
	('MO','MISSOURI'),
	('MT','MONTANA'),
	('NE','NEBRASKA'),
	('NV','NEVADA'),
	('NH','NEW HAMPSHIRE'),
	('NJ','NEW JERSEY'),
	('NM','NEW MEXICO'),
	('NY','NEW YORK'),
	('NC','NORTH CAROLINA'),
	('ND','NORTH DAKOTA'),
	('MP','NORTHERN MARIANA IS'),
	('OH','OHIO'),
	('OK','OKLAHOMA'),
	('OR','OREGON'),
	('PA','PENNSYLVANIA'),
	('PR','PUERTO RICO'),
	('RI','RHODE ISLAND'),
	('SC','SOUTH CAROLINA'),
	('SD','SOUTH DAKOTA'),
	('TN','TENNESSEE'),
	('TX','TEXAS'),
	('UT','UTAH'),
	('VT','VERMONT'),
	('VA','VIRGINIA'),
	('VI','VIRGIN ISLANDS'),
	('WA','WASHINGTON'),
	('WV','WEST VIRGINIA'),
	('WI','WISCONSIN'),
	('WY', 'WYOMING');


-- Adds foreign key constraint to the customer table to enforce data integrity 
ALTER TABLE person.customer 
	WITH CHECK 
	ADD CONSTRAINT fk_customer_state FOREIGN KEY (state) 
		REFERENCES person.state (state_id)
		ON DELETE NO ACTION 
		ON UPDATE CASCADE;

CREATE NONCLUSTERED INDEX ix_customer_state ON person.customer (state);
GO


-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (8, 'State lookup table');