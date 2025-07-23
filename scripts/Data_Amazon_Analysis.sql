SELECT * FROM "Ecom_Data_Amazon" eda;

SELECT category,
max(amount) AS max_amount
FROM "Ecom_Data_Amazon"
GROUP BY category
ORDER BY max_amount DESC;

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
sku
SIZE,
STYLE,
ship_city,
ship_state,
ship_postal_code
FROM "Ecom_Data_Amazon"
WHERE status <> 'Cancelled' AND qty != 0);

-------------------------------------
DROP TABLE IF EXISTS ecommerce_data;


SELECT * FROM ecommerce_data;

SELECT DISTINCT (qty),
count (qty)
FROM ecommerce_data
GROUP BY qty
ORDER BY qty DESC;

SELECT *
FROM ecommerce_data
WHERE qty = 0;