
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
promotion_ids,
ship_city,
ship_state,
ship_postal_code
FROM "Ecom_Data_Amazon"
WHERE status <> 'Cancelled' AND qty != 0 AND amount != 0 AND amount IS NOT NULL);
--Removed canceled orders and rows with zero or missing quantity and amount values. 

-------------------------------------------------------------------------

SELECT * FROM ecommerce_data;

SELECT DISTINCT (qty),
count (qty)
FROM ecommerce_data
GROUP BY qty
ORDER BY qty DESC;

SELECT count(*)
FROM ecommerce_data;

-------------------------------------------------------------------------

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
--Aggregated data by STYLE and category to calculate total sales (amount), total units sold (qty), total cost, 
--and derived metrics like profit and profit margin.

-------------------------------------------------------------------------

SELECT *
FROM amazon_margin
ORDER BY margin DESC;


SELECT 
		PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY margin) AS q1_margin,
		PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY margin) AS q2_margin,
		PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY margin) AS q3_margin,
		PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY profit) AS q1_profit,
		PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY profit) AS q2_profit,
		PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY profit) AS q3_profit,
		percentile_cont(0.25) WITHIN GROUP (ORDER BY quantity_sku) AS q1_volume,
		percentile_cont(0.5) WITHIN GROUP (ORDER BY quantity_sku) AS q2_volume,
		PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY quantity_sku) AS q3_volume
FROM amazon_margin;

CREATE TABLE amazon_classification_full AS (
SELECT style, category, quantity_sku AS volume,
	(CASE
		WHEN quantity_sku <= 7 THEN 'LOW'
		WHEN quantity_sku > 7 AND quantity_sku <=29 THEN 'NORMAL'
		ELSE 'HIGH'
	END) AS volume_class, amount_per_sku AS amount_sum,
	cost_per_unit, (cost_per_unit*quantity_sku) AS cost_sum,
	profit, 
	(CASE
		WHEN profit <=1500 THEN 'LOW'
		WHEN profit >23200 THEN 'HIGH'
		ELSE 'NORMAL'
	END) AS profit_class,
	margin, 
		(CASE
		WHEN margin <=0.38 THEN 'LOW'
		WHEN margin >0.55 THEN 'HIGH'
		ELSE 'NORMAL'
	END) AS margin_class
FROM amazon_margin);
	
/*
iqr_fence_margin = (0.12,0.81)
normal_range_profit = (-31110.82,55847.74)
within_expected_volume_range = (0,190.0)
 */

--Calculated Q1, Q2, Q3 for profit, margin, and volume. Used these to classify products as LOW / NORMAL / HIGH 
--in each category based on thresholds.

-------------------------------------------------------------------------
SELECT count(*) FROM amazon_classification_full ac;
-- #1369

SELECT count(*) FROM amazon_classification ac
WHERE volume<190 AND profit<55847.74 AND margin>0.12 AND margin<0.81;
-- #1193

CREATE TABLE amazon_classification_no_outliers AS (
SELECT * FROM amazon_classification ac
WHERE volume<190 AND profit<55847.74 AND margin>0.12 AND margin<0.81);

--Applied the IQR method to remove extreme values from the dataset, focusing on profit, margin, and volume 
--to create a more realistic data range.
-------------------------------------------------------------------------
-- 2nd quantile calculation

SELECT * FROM amazon_classification_no_outliers;

SELECT 
	PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY volume) AS q1_volume,
	PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY volume) AS q3_volume,
	PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY profit) AS q1_profit,
	PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY profit) AS q3_profit,
	PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY margin) AS q1_margin,
	PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY margin) AS q3_margin
FROM amazon_classification_no_outliers acno;

CREATE TABLE amazon_class_final AS (
SELECT style, category, volume,
	(CASE
		WHEN volume <= 6 THEN 'LOW'
		WHEN volume > 6 AND volume <=54 THEN 'NORMAL'
		ELSE 'HIGH'
	END) AS volume_class, amount_sum,
	cost_per_unit, cost_sum,
	profit, 
	(CASE
		WHEN profit <=1200 THEN 'LOW'
		WHEN profit >14500 THEN 'HIGH'
		ELSE 'NORMAL'
	END) AS profit_class,
	margin, 
		(CASE
		WHEN margin <=0.38 THEN 'LOW'
		WHEN margin >0.55 THEN 'HIGH'
		ELSE 'NORMAL'
	END) AS margin_class
FROM amazon_classification_no_outliers);

--Recomputed quartile thresholds based on the cleaned data. Reclassified all products into LOW / NORMAL / HIGH categories 
--using the new, more robust quartile values.

CREATE TABLE amazon_high_margin AS (
SELECT * FROM amazon_class_final
WHERE margin_class = 'HIGH' AND margin>=0.6
ORDER BY margin DESC);

CREATE TABLE amazon_high_volume_low_margin AS (
SELECT * FROM amazon_class_final
WHERE profit_class = 'NORMAL' AND volume_class = 'HIGH' AND margin_class = 'LOW'
ORDER BY volume DESC profit ASC);

SELECT * FROM amazon_high_volume_low_margin
ORDER BY volume DESC, cost_sum ASC;

--Filtered products into specific focus groups:
	--High-margin products (potential champions)
	--High-volume but low-margin products (potential risks or inefficiencies)

-------------------------------------------------------------------------

CREATE TABLE amazon_risky_products AS (
SELECT * FROM ecommerce_data
WHERE STYLE IN ('JNE1998',
 'JNE1234',
 'JNE3603',
 'JNE3479',
 'JNE3454',
 'JNE3742',
 'JNE3605',
 'JNE3265',
 'JNE3449',
 'JNE3756',
 'JNE3482',
 'SET116',
 'JNE3651',
 'SET188',
 'SET130',
 'SET219',
 'JNE3817',
 'NW015',
 'MEN5003',
 'NW037',
 'NW013',
 'JNE3720',
 'JNE1525',
 'NW001',
 'JNE3261',
 'JNE2100',
 'JNE3689',
 'J0348'));

SELECT * FROM amazon_risky_products;
--Extracted full details of products from the high-volume, low-margin group to examine promotions, 
--fulfillment method (Amazon vs. Merchant), and size variations.
