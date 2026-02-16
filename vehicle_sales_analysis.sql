/* ============================================================
   Vehicle Sales Performance Analysis (SQL)
   Purpose: Quarterly executive KPIs for a vehicle resale business
   Tables used: customer_t, order_t, product_t
   ============================================================ */

-- 1) Total customers who placed orders
SELECT
  COUNT(DISTINCT o.customer_id) AS total_customers
FROM customer_t c
LEFT JOIN order_t o
  ON c.customer_id = o.customer_id;

-- 1b) Customer distribution by state (customers who ordered)
SELECT
  c.state,
  COUNT(DISTINCT c.customer_id) AS total_customers
FROM order_t o
LEFT JOIN customer_t c
  ON c.customer_id = o.customer_id
GROUP BY c.state
ORDER BY total_customers DESC;

-- 2) Top 5 vehicle makers by number of orders
SELECT
  p.vehicle_maker,
  COUNT(*) AS order_count
FROM order_t o
LEFT JOIN product_t p
  ON p.product_id = o.product_id
GROUP BY p.vehicle_maker
ORDER BY order_count DESC
LIMIT 5;

-- 3) Most preferred vehicle maker in each state (by order count)
WITH maker_by_state AS (
  SELECT
    c.state,
    p.vehicle_maker,
    COUNT(*) AS order_count,
    RANK() OVER (
      PARTITION BY c.state
      ORDER BY COUNT(*) DESC
    ) AS rnk
  FROM order_t o
  LEFT JOIN product_t p
    ON p.product_id = o.product_id
  LEFT JOIN customer_t c
    ON c.customer_id = o.customer_id
  GROUP BY c.state, p.vehicle_maker
)
SELECT
  state,
  vehicle_maker,
  order_count
FROM maker_by_state
WHERE rnk = 1
ORDER BY state;

-- 4) Average customer rating overall (map text feedback to numeric score)
WITH ratings AS (
  SELECT
    CASE customer_feedback
      WHEN 'Very Bad'  THEN 1
      WHEN 'Bad'       THEN 2
      WHEN 'Okay'      THEN 3
      WHEN 'Good'      THEN 4
      WHEN 'Very Good' THEN 5
      ELSE NULL
    END AS rating_score
  FROM order_t
)
SELECT
  ROUND(AVG(rating_score), 2) AS avg_rating_overall
FROM ratings;

-- 4b) Average customer rating by quarter
WITH ratings_by_q AS (
  SELECT
    quarter_number,
    CASE customer_feedback
      WHEN 'Very Bad'  THEN 1
      WHEN 'Bad'       THEN 2
      WHEN 'Okay'      THEN 3
      WHEN 'Good'      THEN 4
      WHEN 'Very Good' THEN 5
      ELSE NULL
    END AS rating_score
  FROM order_t
)
SELECT
  quarter_number,
  ROUND(AVG(rating_score), 2) AS avg_rating
FROM ratings_by_q
GROUP BY quarter_number
ORDER BY quarter_number;

-- 5) Feedback distribution (%) by quarter
WITH feedback_counts AS (
  SELECT
    quarter_number,
    SUM(CASE WHEN customer_feedback = 'Very Bad'  THEN 1 ELSE 0 END) AS very_bad,
    SUM(CASE WHEN customer_feedback = 'Bad'       THEN 1 ELSE 0 END) AS bad,
    SUM(CASE WHEN customer_feedback = 'Okay'      THEN 1 ELSE 0 END) AS okay,
    SUM(CASE WHEN customer_feedback = 'Good'      THEN 1 ELSE 0 END) AS good,
    SUM(CASE WHEN customer_feedback = 'Very Good' THEN 1 ELSE 0 END) AS very_good,
    COUNT(*) AS total_feedback
  FROM order_t
  GROUP BY quarter_number
)
SELECT
  quarter_number,
  ROUND(100.0 * very_bad  / total_feedback, 2) AS very_bad_percent,
  ROUND(100.0 * bad       / total_feedback, 2) AS bad_percent,
  ROUND(100.0 * okay      / total_feedback, 2) AS okay_percent,
  ROUND(100.0 * good      / total_feedback, 2) AS good_percent,
  ROUND(100.0 * very_good / total_feedback, 2) AS very_good_percent
FROM feedback_counts
ORDER BY quarter_number;

-- 6) Orders per quarter
SELECT
  quarter_number,
  COUNT(*) AS orders_per_quarter
FROM order_t
GROUP BY quarter_number
ORDER BY quarter_number;

-- 7) Net revenue overall (after discount)
SELECT
  ROUND(SUM((vehicle_price - ((discount / 100.0) * vehicle_price)) * quantity), 2) AS net_revenue_total
FROM order_t;

-- 7b) Net revenue by quarter
WITH revenue_by_q AS (
  SELECT
    quarter_number,
    ROUND(SUM((vehicle_price - ((discount / 100.0) * vehicle_price)) * quantity), 2) AS net_revenue
  FROM order_t
  GROUP BY quarter_number
)
SELECT
  quarter_number,
  net_revenue
FROM revenue_by_q
ORDER BY quarter_number;

-- 7c) Quarter-over-quarter % change in net revenue
WITH revenue_by_q AS (
  SELECT
    quarter_number,
    ROUND(SUM((vehicle_price - ((discount / 100.0) * vehicle_price)) * quantity), 2) AS net_revenue
  FROM order_t
  GROUP BY quarter_number
)
SELECT
  quarter_number,
  net_revenue,
  ROUND(
    100.0 * (net_revenue - LAG(net_revenue) OVER (ORDER BY quarter_number))
    / NULLIF(LAG(net_revenue) OVER (ORDER BY quarter_number), 0),
    2
  ) AS qoq_percent_change
FROM revenue_by_q
ORDER BY quarter_number;

-- 8) Revenue + orders per quarter (trend table)
SELECT
  quarter_number,
  ROUND(SUM((vehicle_price - ((discount / 100.0) * vehicle_price)) * quantity), 2) AS net_revenue,
  COUNT(order_id) AS orders_per_quarter
FROM order_t
GROUP BY quarter_number
ORDER BY quarter_number;

-- 9) Average discount by credit card type
SELECT
  c.credit_card_type,
  ROUND(AVG(o.discount), 2) AS avg_discount
FROM customer_t c
JOIN order_t o
  ON o.customer_id = c.customer_id
GROUP BY c.credit_card_type
ORDER BY avg_discount DESC;

-- 10) Average shipping time by quarter
-- NOTE: Your DB must support DATEDIFF(date2, date1). If using MySQL: DATEDIFF(ship_date, order_date)
SELECT
  quarter_number,
  ROUND(AVG(DATEDIFF(ship_date, order_date)), 2) AS avg_days_to_ship
FROM order_t
GROUP BY quarter_number
ORDER BY quarter_number;
