BULK INSERT instac_order_products_prior
FROM 'E:\DA\Microsoft SQL Server\MSSQL16.SQLEXPRESS\instac_order_products__prior.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);


BULK INSERT instac_products
FROM 'E:\DA\Microsoft SQL Server\MSSQL16.SQLEXPRESS\instac_products.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);

-- checking row counts --
SELECT COUNT(*) AS total_orders FROM instac_orders;
SELECT COUNT(*) AS total_prior FROM instac_order_products_prior;
SELECT COUNT(*) AS total_train FROM instac_order_products__train;
SELECT COUNT(*) AS total_products FROM instac_products;
SELECT COUNT(*) AS total_aisles FROM instac_aisles;
SELECT COUNT(*) AS total_departments FROM instac_departments;
SELECT COUNT(*) AS total_walmart FROM walmart_data;

-- checking missing values(NULL) --
SELECT COUNT(*) AS [null days prior]
FROM [dbo].[instac_orders]
WHERE days_since_prior_order IS NULL


SELECT COUNT(*) AS null_product_names
FROM instac_products
WHERE product_name IS NULL;

SELECT COUNT(*) AS null_sales
FROM walmart_data
WHERE Weekly_Sales IS NULL;

--- checking NULLs or missing values for every table --
DECLARE @TableName NVARCHAR(100) = 'walmart_data';
DECLARE @sql NVARCHAR(MAX) = '';

SELECT @sql = @sql + 
    'SELECT ''' + c.name + ''' AS column_name, COUNT(*) AS null_count ' +
    'FROM ' + @TableName + ' WHERE ' + c.name + ' IS NULL UNION ALL '
FROM sys.columns c
WHERE c.object_id = OBJECT_ID(@TableName);

-- Remove last UNION ALL
SET @sql = LEFT(@sql, LEN(@sql) - 10);

EXEC sp_executesql @sql;

-- checking duplicates ---

-- for orders (order_id should be unique) --
SELECT order_id, COUNT(*) AS cnt
FROM instac_orders
GROUP BY order_id
HAVING COUNT(*) > 1;


-- for order_products_train (order_id,product_id should be unique) --
SELECT order_id, product_id, COUNT(*) AS cnt
FROM instac_order_products__train
GROUP BY order_id, product_id
HAVING COUNT(*) > 1;

-- for order_products_prior (order_id,product_id should be unique) --
SELECT order_id, product_id, COUNT(*) AS cnt
FROM instac_order_products_prior
GROUP BY order_id, product_id
HAVING COUNT(*) > 1;

-- for products (product_id should be unique) --
SELECT product_id, COUNT(*) AS cnt
FROM instac_products
GROUP BY product_id
HAVING COUNT(*) > 1;


-- for aisles (aisle_id should be unique) --
SELECT aisle_id, COUNT(*) AS cnt
FROM instac_aisles
GROUP BY aisle_id
HAVING COUNT(*) > 1;

-- for departments (department_id should be unique) --
SELECT department_id, COUNT(*) AS cnt
FROM instac_departments
GROUP BY department_id
HAVING COUNT(*) > 1;


-- for walmart-data (store,date should be unique) --
SELECT Store, Date, COUNT(*) AS cnt
FROM walmart_data
GROUP BY Store, Date
HAVING COUNT(*) > 1;


-- Fact Table: Orders (Transaction-level) --
CREATE TABLE fact_orders (
       order_id INT PRIMARY KEY,
       user_id INT,
       order_number INT,
       order_dow INT,
       order_hour_of_day INT,
       days_since_prior_order INT,
       total_items INT,
       reordered_items INT
);

-- DIM: Customers --
CREATE TABLE dim_customers (
      user_id INT PRIMARY KEY,
      first_order_number INT,
      total_orders INT
);

-- DIM: products --
CREATE TABLE dim_products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(255),
    aisle_id INT,
    aisle VARCHAR(100),
    department_id INT,
    department VARCHAR(100)
);


-- DIM: Dates (based on Walmart sales)
CREATE TABLE dim_date (
    date DATE PRIMARY KEY,
    day_of_week INT,
    week_num INT,
    month_num INT,
    year_num INT,
    holiday_flag BIT
);

-- FACT: Walmart Sales
CREATE TABLE walmart_sales (
    Store INT,
    Date DATE,
    Weekly_Sales FLOAT,
    Holiday_Flag BIT,
    Temperature FLOAT,
    Fuel_Price FLOAT,
    CPI FLOAT,
    Unemployment FLOAT
);


-- Populate the TABLES

-- fact_orders
INSERT INTO fact_orders (order_id, user_id, order_number, order_dow, order_hour_of_day, days_since_prior_order, total_items, reordered_items)
SELECT 
    o.order_id,
    o.user_id,
    o.order_number,
    o.order_dow,
    o.order_hour_of_day,
    o.days_since_prior_order,
    COUNT(op.product_id) AS total_items,
    SUM(op.reordered) AS reordered_items
FROM instac_orders o
JOIN instac_order_products_prior op
    ON o.order_id = op.order_id
GROUP BY o.order_id, o.user_id, o.order_number, o.order_dow, o.order_hour_of_day, o.days_since_prior_order;


-- dim customers
INSERT INTO dim_customers(user_id, first_order_number, total_orders)
SELECT 
    user_id,
    MIN(order_number) AS first_order_number,
    MAX(order_number) AS total_orders
FROM instac_orders
GROUP BY user_id;

-- dim products
INSERT INTO dim_products (product_id, product_name, aisle_id, aisle, department_id, department)
SELECT 
    p.product_id, p.product_name, p.aisle_id, a.aisle, p.department_id, d.department
FROM instac_products p
JOIN instac_aisles a ON p.aisle_id = a.aisle_id
JOIN instac_departments d ON p.department_id = d.department_id;

-- dim date
INSERT INTO dim_date (date, day_of_week, week_num, month_num, year_num, holiday_flag)
SELECT DISTINCT 
    Date,
    DATEPART(WEEKDAY, Date) AS day_of_week,
    DATEPART(WEEK, Date) AS week_num,
    DATEPART(MONTH, Date) AS month_num,
    DATEPART(YEAR, Date) AS year_num,
    Holiday_Flag
FROM walmart_data;


-- walmart sales
INSERT INTO walmart_sales (Store, Date, Weekly_Sales, Holiday_Flag, Temperature, Fuel_Price, CPI, Unemployment)
SELECT 
    Store, 
    Date, 
    Weekly_Sales, 
    Holiday_Flag,
    Temperature, 
    Fuel_Price, 
    CPI, 
    Unemployment
FROM walmart_data;


select count(*) from dim_customers
select count(*) from dim_date
select count(*) from walmart_sales

select * from fact_orders
