-----------------------------------------------------------------------------------
-- Script 019                                                                 
--       
-- HANDLING MULTI-LANGUAGE DATA                   
--      
-- #1  Basic collation check
-- #2  Multi-language data gotchas
-- #3  Sorting single-column multilanguage data
-- #4  Migration to multi-languages
-- #5  Changing a customer name from varchar to nvarchar
--
-----------------------------------------------------------------------------------
USE OnlineStore;
GO

 
-----------------------------------------------------------------------------------
-- #1  Basic collation check
-----------------------------------------------------------------------------------

-- Gets the collation of SQL Server
SELECT DATABASEPROPERTYEX ('OnlineStore', 'Collation') AS 'database_collation';


-- Further describes the SQL Server collation
SELECT description
FROM sys.fn_helpcollations()
WHERE name = 'Japanese_CI_AS';


-- Gets collations of columns in the product table
SELECT 
	column_name, 
	collation_name
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'product' 
  AND table_schema = 'production';


-- Character-based Windows collations
SELECT
	name, 
	description
FROM sys.fn_helpcollations()
WHERE name NOT LIKE 'sql_%' 
  AND name NOT LIKE '%_bin%';

-- Binary Windows collations
SELECT
	name, 
	description
FROM sys.fn_helpcollations()
WHERE name NOT LIKE 'sql_%' 
  AND name LIKE '%_bin%';


-- Character-based SQL collations
SELECT
	name, 
	description
FROM sys.fn_helpcollations()
WHERE name LIKE 'sql_%' 
  AND name NOT LIKE '%_bin%';


-- Binary SQL collations
SELECT 
	name, 
	description
FROM sys.fn_helpcollations()
WHERE name LIKE 'sql_%' 
  AND name LIKE '%_bin%';


--
-- Compares case sensitive vs case insensitive collations
--
CREATE TABLE cs_vs_ci_collation_test_table (
	ci_data NVARCHAR(10) COLLATE Latin1_General_100_CI_AS_SC,
	cs_data NVARCHAR(10) COLLATE Latin1_General_100_CS_AS_SC
);

INSERT INTO cs_vs_ci_collation_test_table(ci_data, cs_data) VALUES ('Computer','Computer');

-- Returns a single row
SELECT * 
FROM cs_vs_ci_collation_test_table 
WHERE ci_data = 'computer';

-- Does not return any rows
SELECT * 
FROM cs_vs_ci_collation_test_table 
WHERE cs_data = 'computer';


DROP TABLE IF EXISTS cs_vs_ci_collation_test_table;

-----------------------------------------------------------------------------------
-- #2  Multi-language data gotchas
-----------------------------------------------------------------------------------

--
-- When a collation can hit performance (VARCHAR=NVARCHAR with SQL collation)
--
CREATE TABLE collation_test (
  collation_test_id				INT IDENTITY PRIMARY KEY,
  non_unicode_sql_collation		VARCHAR(50)		COLLATE SQL_Latin1_General_CP1_CI_AS,
  non_unicode_win_collation		VARCHAR(50)		COLLATE Latin1_General_100_CI_AS_SC,
  unicode_sql_collation			NVARCHAR(50)	COLLATE SQL_Latin1_General_CP1_CI_AS,
  unicode_win_collation			NVARCHAR(50)	COLLATE Latin1_General_100_CI_AS_SC,
  INDEX ix_non_unicode_sql_collation NONCLUSTERED (non_unicode_sql_collation),
  INDEX ix_non_unicode_win_collation NONCLUSTERED (non_unicode_win_collation),
  INDEX ix_unicode_sql_collation NONCLUSTERED (unicode_sql_collation),
  INDEX ix_unicode_win_collation NONCLUSTERED (unicode_win_collation)
);

DECLARE @counter INT = 1;

WHILE @counter <= 10000
BEGIN
    INSERT INTO collation_test
    SELECT  
        RIGHT('0000000' + CAST(@Counter AS  VARCHAR(7)), 7), 
        RIGHT('0000000' + CAST(@Counter AS  VARCHAR(7)), 7), 
        RIGHT('0000000' + CAST(@Counter AS NVARCHAR(7)), 7),
        RIGHT('0000000' + CAST(@Counter AS NVARCHAR(7)), 7);
    
    SET @counter = @counter + 1;
END;


-- Index seek
SELECT non_unicode_sql_collation FROM collation_test WHERE non_unicode_sql_collation =　'0000832';
-- Index seek (Despite implicit conversion)
SELECT non_unicode_win_collation FROM collation_test WHERE non_unicode_win_collation = N'0000832';
-- Because of the data type precedence the varchar data is converted
-- into the nvarchar. For Windows collations this is not a big problem but for SQL collations
-- it causes an index scan
SELECT non_unicode_sql_collation FROM collation_test WHERE non_unicode_sql_collation = N'0000832';
-- Index seek
SELECT unicode_sql_collation FROM collation_test WHERE unicode_sql_collation =　'0000832';
-- Index seek
SELECT unicode_win_collation FROM collation_test WHERE unicode_win_collation = N'0000832';

-- Clean up
DROP TABLE IF EXISTS dbo.collation_test;


--
-- Demonstrates problems of comparing strings created under different language settings
--
BEGIN TRANSACTION
DECLARE @current_language NVARCHAR(20) = (SELECT @@LANGUAGE AS CurrentLanguage);
-- Retrieve the name of the current month in English
SET LANGUAGE 'English';
DECLARE @english_month_text NVARCHAR(20) = (SELECT DATENAME(MONTH, GETDATE()) AS [MonthNameInEnglish]);
DECLARE @english_month_int INT = (SELECT DATEPART(MONTH, GETDATE()) AS CurrentYear);
-- Retrieve the name of the current month in Polish
SET LANGUAGE 'Polish';
DECLARE @polish_month_text NVARCHAR(20) = (SELECT DATENAME(MONTH, GETDATE()) AS [MonthNameInEnglish]);
DECLARE @polish_month_int INT = (SELECT DATEPART(MONTH, GETDATE()) AS CurrentYear);
SET LANGUAGE @current_language;

SELECT 
	@english_month_text		AS 'english_month_text', 
	@polish_month_text		AS 'polish_month_text',
	@english_month_int		AS 'english_month_int', 	
	@polish_month_int		AS 'polish_month_int'; 

ROLLBACK

-----------------------------------------------------------------------------------
-- #3  Sorting single-column multilanguage data
--     Scripts based on the solution presented in the below link
--     https://learn.microsoft.com/en-us/archive/technet-wiki/31194.t-sql-sort-data-by-multiple-languages
-----------------------------------------------------------------------------------

CREATE TABLE multi_language (
    unicode_data NVARCHAR(200),
    collation CHAR(5)
);
GO
 
-- Seeds the table with 9 entries in 3 languages
INSERT INTO multi_language (unicode_data, collation)
	VALUES
	(N'Azure SQLデータベース',		'jp-JP'),
	(N'データベース入門',				'jp-JP'),
	(N'Introduction to Databases',	'en-US'),
	(N'Database Systems',			'en-US'),
	(N'Azure SQL Baza Danych',		'pl-PL'),
	(N'データベース',					'jp-JP'),
	(N'Azure SQL Database',			'en-US'),
	(N'Wprowadzenie do Baz Danych',	'pl-PL'),
	(N'Systemy Baz Danych',			'pl-PL');
GO

-- Shows the default sort order 
SELECT * FROM multi_language;


-- Shows data where each language is sorted according to its own collation
SELECT 
	unicode_data,
	collation
FROM (
    SELECT
		unicode_data,
		collation,
        ROW_NUMBER() OVER (ORDER BY unicode_data Collate SQL_Latin1_General_CP1_CI_AS	) 'en-US',
        ROW_NUMBER() OVER (ORDER BY unicode_data Collate Polish_CI_AS					) 'pl-PL',
	    ROW_NUMBER() OVER (ORDER BY unicode_data Collate Japanese_XJIS_100_CI_AS		) 'jp-JP'
    FROM multi_language ml
) t
ORDER BY collation,
     CASE
        WHEN collation = 'pl-PL' THEN [pl-PL] 
        WHEN collation = 'en-US' THEN [en-US]
        WHEN collation = 'jp-JP' THEN [jp-JP]
	END;
GO


SELECT 
	unicode_data,
	collation
FROM (
    SELECT
		unicode_data,
		collation,
        ROW_NUMBER() OVER (ORDER BY unicode_data Collate SQL_Latin1_General_CP1_CI_AS	) 'en-US',
        ROW_NUMBER() OVER (ORDER BY unicode_data Collate Polish_CI_AS					) 'pl-PL',
	    ROW_NUMBER() OVER (ORDER BY unicode_data Collate Japanese_XJIS_100_CI_AS		) 'jp-JP'
    FROM multi_language ml
) t
ORDER BY      
	CASE
        WHEN collation = 'jp-JP' THEN 1 -- Japanese first 
        WHEN collation = 'pl-PL' THEN 2 -- Polish second
        WHEN collation = 'en-US' THEN 3 -- English third 
	END,
	CASE
        WHEN collation = 'pl-PL' THEN [pl-PL] 
        WHEN collation = 'en-US' THEN [en-US]
        WHEN collation = 'jp-JP' THEN [jp-JP]
	END;
GO



-- Clean up
DROP TABLE IF EXISTS dbo.multi_language;

-----------------------------------------------------------------------------------
-- #4  Migration to multi-languages
--     (Modifying product_category table to support multiple languages)
-----------------------------------------------------------------------------------
CREATE TABLE production.language (
	language_id	CHAR(5),
	name		NVARCHAR(50),
	CONSTRAINT pk_language PRIMARY KEY (language_id)
);
GO

INSERT INTO production.language (
	language_id, 
	name
) 
VALUES -- language_id follows ISO 639-1 standard and ISO 3166-1 Alpha-2 standard
	('en-US','English'),
	('pl-PL','Polski'),
	('ja-JP','日本語');


CREATE TABLE production.product_category_translation(
	product_category_translation_id	INT				NOT NULL,
	language_id						CHAR(5)			NOT NULL,
	product_category_name			NVARCHAR (100)	NOT NULL,
	is_default						BIT				NOT NULL
	CONSTRAINT pk_product_category_translation PRIMARY KEY (product_category_translation_id, language_id),
	CONSTRAINT fk_product_category_translation_product_category FOREIGN KEY (product_category_translation_id) 
		REFERENCES production.product_category (product_category_id) 
		ON DELETE CASCADE,
	CONSTRAINT fk_product_category_translation_language FOREIGN KEY (language_id) 
		REFERENCES production.language (language_id) 
		ON DELETE NO ACTION
);
GO

INSERT INTO production.product_category_translation (
	product_category_translation_id, 
	language_id,
	product_category_name,
	is_default
) 
VALUES
	-- Adds English translations
	(1,'en-US',N'Hardware Products',1),
	(2,'en-US',N'Software Products',1),
	(3,'en-US',N'Personal Devices',1),
	(4,'en-US',N'Audio Devices',1),
	(5,'en-US',N'Cameras',1),
	(6,'en-US',N'Gaming Consoles',1),
	(7,'en-US',N'Wearable Fitness Devices',1),
	(8,'en-US',N'Other Hardware Products',1),
	(9,'en-US',N'Smartphones',1),
	(10,'en-US',N'Tablets',1),
	(11,'en-US',N'Laptops',1),
	(12,'en-US',N'Smartwatches',1),
	(13,'en-US',N'E-readers',1),
	(14,'en-US',N'Headphones',1),
	(15,'en-US',N'Earbuds',1),
	(16,'en-US',N'Bluetooth Speakers',1),
	(17,'en-US',N'Home Theater Systems',1),
	(18,'en-US',N'Digital Cameras',1),
	(19,'en-US',N'Action Cameras',1),
	(20,'en-US',N'DSLR Cameras',1),
	(21,'en-US',N'Slot Machines',1),
	(22,'en-US',N'Gaming Stations',1),
	(23,'en-US',N'Switches',1),
	(24,'en-US',N'Fitness Trackers',1),
	(25,'en-US',N'Smartwatches',1),
	(26,'en-US',N'Gaming Smartphones',1),
	(27,'en-US',N'Rugged Smartphones',1),
	(28,'en-US',N'Foldable Smartphones',1),
	(29,'en-US',N'Business Smartphones',1),
	(30,'en-US',N'Gaming Tablets',1),
	(31,'en-US',N'E-reader Tablets',1),
	(32,'en-US',N'Business Tablets',1),
	(33,'en-US',N'Ultrabooks',1),
	(34,'en-US',N'2-in-1 Laptops',1),
	(35,'en-US',N'Rugged Laptops',1),
	(36,'en-US',N'Fitness Smartwatches',1),
	(37,'en-US',N'Gaming Smartwatches',1),
	(38,'en-US',N'Waterproof E-readers',1),
	(39,'en-US',N'E-ink E-readers',1),
	(40,'en-US',N'Basic E-readers',1),
	(41,'en-US',N'Over-Ear Headphones',1),
	(42,'en-US',N'On-Ear Headphones',1),
	(43,'en-US',N'Gaming Headphones',1),
	(44,'en-US',N'Language Learning',1),
	(45,'en-US',N'Business Applications',1),
	-- Adds Polish translations
	(1,'pl-PL',N'Sprzęt komputerowy',0),
	(2,'pl-PL',N'Programy komputerowe',0),
	(3,'pl-PL',N'Urządzenia osobiste',0),
	(4,'pl-PL',N'Urządzenia audio',0),
	(5,'pl-PL',N'Aparaty fotograficzne',0),
	(6,'pl-PL',N'Konsole do gier',0),
	(7,'pl-PL',N'Urządzenia typu fitness',0),
	(8,'pl-PL',N'Inne produkty typu hardware',0),
	(9,'pl-PL',N'Smartfony',0),
	(10,'pl-PL',N'Tablety',0),
	(11,'pl-PL',N'Laptopy',0),
	(12,'pl-PL',N'Smartwatche',0),
	(13,'pl-PL',N'Czytniki e-booków',0),
	(14,'pl-PL',N'Słuchawki',0),
	(15,'pl-PL',N'Słuchawki douszne typu earbuds',0),
	(16,'pl-PL',N'Głośniki Bluetooth',0),
	(17,'pl-PL',N'Systemy kina domowego',0),
	(18,'pl-PL',N'Aparaty cyfrowe',0),
	(19,'pl-PL',N'Aparaty sportowe',0),
	(20,'pl-PL',N'Aparaty cyfrowe lustrzanki',0),
	(21,'pl-PL',N'Automaty do gry',0),
	(22,'pl-PL',N'Stacje do gier',0),
	(23,'pl-PL',N'Switch',0),
	(24,'pl-PL',N'Fitness trackers',0),
	(25,'pl-PL',N'Smartwatche',0),
	(26,'pl-PL',N'Smartfony do gier',0),
	(27,'pl-PL',N'Smartfony typu rugged',0),
	(28,'pl-PL',N'Składane smartfony',0),
	(29,'pl-PL',N'Smartfony biznesowe',0),
	(30,'pl-PL',N'Tablety do gier',0),
	(31,'pl-PL',N'Tablety do czytania e-booków',0),
	(32,'pl-PL',N'Tablety biznesowe',0),
	(33,'pl-PL',N'Ultrabooki',0),
	(34,'pl-PL',N'Laptopy 2 w 1',0),
	(35,'pl-PL',N'Laptopy typu rugged',0),
	(36,'pl-PL',N'Smartwatche fitness',0),
	(37,'pl-PL',N'Smartwatche do gier',0),
	(38,'pl-PL',N'Wodoodporne czytniki e-booków',0),
	(39,'pl-PL',N'Czytniki e-booków z ekranem E-ink',0),
	(40,'pl-PL',N'Tradycyjne czytniki e-booków',0),
	(41,'pl-PL',N'Słuchawki nauszne',0),
	(42,'pl-PL',N'Słuchawki douszne',0),
	(43,'pl-PL',N'Słuchawki do gier',0),
	(44,'pl-PL',N'Nauka języków',0),
	(45,'pl-PL',N'Aplikacje biznesowe',0),	
	-- Adds Japanese translations
	(1,'ja-JP',N'ハードウェア製品',0),
	(2,'ja-JP',N'ソフトウェア製品',0),
	(3,'ja-JP',N'パーソナルデバイス',0),
	(4,'ja-JP',N'オーディオ機器',0),
	(5,'ja-JP',N'カメラ',0),
	(6,'ja-JP',N'ゲーム機',0),
	(7,'ja-JP',N'ウェアラブルフィットネスデバイス',0),
	(8,'ja-JP',N'その他のハードウェア製品',0),
	(9,'ja-JP',N'スマートフォン',0),
	(10,'ja-JP',N'タブレット',0),
	(11,'ja-JP',N'ノートパソコン',0),
	(12,'ja-JP',N'スマートウォッチ',0),
	(13,'ja-JP',N'電子書籍リーダー',0),
	(14,'ja-JP',N'ヘッドホン',0),
	(15,'ja-JP',N'イヤホン',0),
	(16,'ja-JP',N'Bluetoothスピーカー',0),
	(17,'ja-JP',N'ホームシアターシステム',0),
	(18,'ja-JP',N'デジタルカメラ',0),
	(19,'ja-JP',N'アクションカメラ',0),
	(20,'ja-JP',N'一眼レフカメラ',0),
	(21,'ja-JP',N'スロットマシン',0),
	(22,'ja-JP',N'家庭用ゲーム機',0),
	(23,'ja-JP',N'スイッチ',0),
	(24,'ja-JP',N'フィットネストラッカー',0),
	(25,'ja-JP',N'スマートウォッチ',0),
	(26,'ja-JP',N'ゲームスマートフォン',0),
	(27,'ja-JP',N'Ruggedスマートフォン',0),
	(28,'ja-JP',N'折りたたみスマホ',0),
	(29,'ja-JP',N'ビジネス用スマートフォン',0),
	(30,'ja-JP',N'ゲーミングタブレット',0),
	(31,'ja-JP',N'電子書籍リーダータブレット',0),
	(32,'ja-JP',N'ビジネス用タブレット',0),
	(33,'ja-JP',N'ウルトラブック',0),
	(34,'ja-JP',N'2-in-1 ノートパソコン',0),
	(35,'ja-JP',N'頑丈なノートパソコン',0),
	(36,'ja-JP',N'フィットネススマートウォッチ',0),
	(37,'ja-JP',N'ゲーミングスマートウォッチ',0),
	(38,'ja-JP',N'防水電子書籍リーダー',0),
	(39,'ja-JP',N'電子インク電子書籍リーダー',0),
	(40,'ja-JP',N'電子書籍リーダー',0),
	(41,'ja-JP',N'オーバーイヤーヘッドホン',0),
	(42,'ja-JP',N'オンイヤーヘッドホン',0),
	(43,'ja-JP',N'ゲーミングヘッドホン',0),
	(44,'ja-JP',N'言語学習',0),
	(45,'ja-JP',N'ビジネスアプリケーション',0);


-- Gets a product with id=29 (japanese language)
SELECT 
	pc.product_category_id,
	pc.name AS 'product_category_default_name',
	pct.product_category_name AS 'product_category_name_in_japanese'
FROM production.product_category pc 
   LEFT JOIN production.product_category_translation pct 
             ON pc.product_category_id = pct.product_category_translation_id 
            AND pct.language_id = 'ja-JP'
WHERE pc.product_category_id = 29;

-----------------------------------------------------------------------------------
-- #5  Changing customer's first_name and last_name from varchar to nvarchar
-----------------------------------------------------------------------------------
-- Accent in the first_name value is lost after saving because of the column type being varchar
INSERT INTO person.customer (
	first_name, 
	last_name,
	address, 
	city, 
	state, 
	zip_code, 
	phone,  
	email
) 
VALUES
	(N'Andréa', N'Collet','1234 Maple Lane', 'Fayetteville 2', 'NC','94582','9128051234','a.collet@mail.com');

-- Adds new NVARCHAR columns to store customer's first and last names
ALTER TABLE person.customer ADD first_name_nvarchar NVARCHAR(200);
ALTER TABLE person.customer ADD last_name_nvarchar NVARCHAR(200);
GO

-- Migrates the data from varchar columns to nvarchar
DECLARE @row_count INT = 1;
DECLARE @batch_size INT = 100;
DECLARE @min_id INT = 0;
DECLARE @max_id INT = @batch_size;

WHILE @row_count > 0
BEGIN
	-- Update in batches based on the customer_id range
	UPDATE person.customer
	SET first_name_nvarchar = CONVERT(NVARCHAR(200), first_name),
		last_name_nvarchar = CONVERT(NVARCHAR(200), last_name)
	WHERE customer_id > @min_id -- Start of the batch range (exclusive)
	  AND customer_id <= @max_id; -- End of the batch range (inclusive)

	-- Gets the count of affected rows
	SET @row_count = @@ROWCOUNT;

	-- Moves the range for the next batch
	SET @min_id = @max_id;
	SET @max_id = @max_id + @batch_size;

	-- Optional delay to avoid impacting server performance
	WAITFOR DELAY '00:00:00.100';
END

-- Drops the old VARCHAR columns
ALTER TABLE person.customer DROP COLUMN first_name;
ALTER TABLE person.customer DROP COLUMN last_name;
GO


-- Renames the new columns
EXEC sp_rename 'person.customer.first_name_nvarchar', 'first_name', 'COLUMN';
EXEC sp_rename 'person.customer.last_name_nvarchar', 'last_name', 'COLUMN';
GO

INSERT INTO person.customer (
	first_name, 
	last_name,
	address, 
	city, 
	state, 
	zip_code, 
	phone,  
	email
) 
VALUES
	(N'Andréa', N'Collet','1234 Maple Lane', 'Fayetteville 2', 'NC','94582','9128051234','a.collet@mail.com');

-----------------------------------------------------------------------------------
-- Updates the schema migration history table
-----------------------------------------------------------------------------------
INSERT INTO dbo.migration_history(migration_history_id, [description]) 
	VALUES (19, 'Handling multi-language data');

