
SELECT * FROM "Ecom_Data_Amazon" eda;

SELECT column_name, data_type
FROM information_schema.COLUMNS 
WHERE table_name = 'Ecom_Data_Amazon';


SELECT count(DISTINCT asin) AS no_asin
FROM "Ecom_Data_Amazon";

CREATE TABLE ecommerce_data AS(
SELECT 
date,
status,
fulfilment,
sales_channel_,
amount,
qty,
category,
sku,
SIZE,
STYLE,
ship_city,
ship_state,
ship_postal_code
FROM "Ecom_Data_Amazon"
WHERE status <> 'Cancelled' AND qty != 0 AND amount != 0 AND amount IS NOT NULL);

-------------------------------------------------------------------------
DROP TABLE IF EXISTS ecommerce_data;

SELECT * FROM ecommerce_data;

SELECT DISTINCT (qty),
count (qty)
FROM ecommerce_data
GROUP BY qty
ORDER BY qty DESC;

SELECT count(*)
FROM ecommerce_data;

-------------------------------------------------------------------------
# Which products generate high sales but low profits?

CREATE TABLE amazon_margin AS(
WITH step_1 AS 
(
	SELECT STYLE,category,
	sum(qty) AS quantity_sku,
	sum(amount) AS amount_per_sku,
	cost_per_unit
	FROM ecommerce_data ed
	GROUP BY STYLE,category,cost_per_unit
	ORDER BY amount_per_sku ASC),
step_2 AS (
	SELECT *, (amount_per_sku-(cost_per_unit*quantity_sku)) AS profit
	FROM step_1),
step_3 AS (
	SELECT *, round(NULLIF((profit/amount_per_sku),0)::NUMERIC,2) AS margin
	FROM step_2
)
SELECT * FROM step_3);

-------------------------------------------------------------------------
SELECT max(margin),
min(margin)
FROM amazon_margin;

SELECT *
FROM amazon_margin
ORDER BY margin DESC;