-- =============================================
-- ShopKart India - Revenue Optimization Analysis
-- Author: Paras Grover
-- Tools Used: MySQL
-- =============================================

-- =============================================
-- PHASE 1: Revenue Health & Stability
-- =============================================

-- 1. Monthly Revenue
SELECT 
     date_format(o.order_date, '%Y-%M') as months,
	 SUM(SP.amount) as total_revenue
FROM sucessful_payments as SP
JOIN orders as o
USING (order_id) 
GROUP BY months
ORDER BY months;

-- 2. Month-over-Month Growth
WITH monthly as ( 
	 SELECT date_format(o.order_date, '%Y-%M') as months,
     SUM(SP.amount) as total_revenue
FROM sucessful_payments SP
JOIN orders as o
USING (order_id) 
GROUP BY date_format(o.order_date, '%Y-%M')
)
SELECT 
     months, 
     total_revenue,
     (coalesce(round(((total_revenue - prev_month)/prev_month)*100,2),0)) as MOM_growth
FROM (select *, lag(total_revenue, 1) over(order by months) as prev_month from monthly) as compare;

-- Revenue volatility
WITH volatility as (
         SELECT 
         date_format(o.order_date, '%Y-%M') as months,
         SUM(SP.amount) as total_revenue
FROM sucessful_payments SP
JOIN orders as o
USING (order_id) 
GROUP BY date_format(o.order_date, '%Y-%M')
)

SELECT 
   round(avg(total_revenue),2) as avg_monthly,
   ROUND(STDDEV(total_revenue),2) AS volatility,
   ROUND((STDDEV(total_revenue)/AVG(total_revenue))*100,2) AS volatility_percent
FROM volatility;

-- Sharp Revenue drop Detection 
WITH monthly as (
         SELECT date_format(o.order_date, '%Y-%M') as months,
         SUM(SP.amount) as revenue
FROM sucessful_payments SP
JOIN orders as o
USING (order_id) 
GROUP BY months),
 growth as 
		(SELECT 
			months,
		    revenue,
            LAG(revenue) over(order by months) as prev_rev,
         concat(ROUND(((revenue - LAG(revenue) over(order by months)) / LAG(revenue) over(order by months))*100,2),'%') as growth_percent 
FROM monthly
) 
SELECT * from growth
where growth_percent <= '-15';

-- 2023-2024 YoY growth pattern
WITH compare as (
       SELECT  
           year(o.order_date) as years,
           SUM(SP.amount) as revenue
FROM sucessful_payments SP
JOIN orders as o
USING (order_id) 
GROUP BY years),
growth as ( 
       SELECT 
		    years,
		    revenue,
			LAG(revenue) over(order by years) as prev_rev,
            (ROUND(((revenue - LAG(revenue) over(order by years)) / LAG(revenue) over(order by years))*100,2)) as growth_percent 
FROM compare) 

SELECT * FROM growth;

-- =============================================
-- PHASE 2: Revenue Drivers
-- =============================================

-- Revenue by Category
SELECT
      p.category,
      round(SUM(sp.amount),2) as revenue
FROM products as p
JOIN order_items as oi
USING(product_id)
JOIN sucessful_payments as sp
using (order_id)
GROUP by p.category;

-- Revenue by customer segment
WITH segment_rev as (
          SELECT 
              c.customer_segment,
              sum(sp.amount) as revenue
FROM customers as c
JOIN orders as o
USING(customer_id)
JOIN sucessful_payments as sp
USing(order_id)
GROUP BY c.customer_segment)

SELECT 
      customer_segment,
      ROUND(revenue,2) as revenue,
      (ROUND((revenue / sum(revenue) over()) *100,2)) as revenue_percent from segment_rev
       order by revenue desc;


-- =============================================
-- PHASE 3: Revenue Leakage
-- =============================================

-- Revenue Leakage Percentage
WITH total_rev AS (
    SELECT SUM(amount) AS revenue
    FROM successful_payments
),
refund AS (
    SELECT SUM(refund_amount) AS refund
    FROM returns
)
SELECT 
     (ROUND((refund / revenue) * 100, 2)) AS revenue_leakage_percent
FROM total_rev, refund;

-- =============================================
-- PHASE 4: Customer Retention
-- =============================================

-- Repeat vs One-Time Customers
WITH customer_orders AS (
    SELECT 
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(sp.amount) AS total_spent
    FROM orders o
    JOIN successful_payments sp USING(order_id)
    GROUP BY o.customer_id
)
SELECT 
    CASE 
        WHEN total_orders = 1 THEN 'One-Time'
        ELSE 'Repeat'
    END AS customer_type,
    COUNT(*) AS customer_count,
    SUM(total_spent) AS revenue
FROM customer_orders
GROUP BY customer_type;

