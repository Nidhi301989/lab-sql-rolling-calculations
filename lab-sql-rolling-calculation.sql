--- 1.Get number of monthly active customers.
SELECT
    YEAR(rental_date) AS year,
    MONTH(rental_date) AS month,
    COUNT(DISTINCT customer_id) AS monthly_active_customers
FROM rental
GROUP BY YEAR(rental_date), MONTH(rental_date)
ORDER BY YEAR(rental_date), MONTH(rental_date)
LIMIT 0, 1000;


-- 2.Active users in the previous month.
SELECT 
    COUNT(DISTINCT customer_id) AS active_users
FROM 
    rental
WHERE 
    rental_date >= DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m-01') AND
    rental_date < DATE_FORMAT(NOW(), '%Y-%m-01');

-- 3.Percentage change in the number of active customers.
WITH monthly_activity AS (
    -- Gather activity (rentals or payments) per month
    SELECT
        EXTRACT(YEAR FROM r.rental_date) AS year,
        EXTRACT(MONTH FROM r.rental_date) AS month,
        r.customer_id
    FROM
        rental r
    UNION
    SELECT
        EXTRACT(YEAR FROM p.payment_date) AS year,
        EXTRACT(MONTH FROM p.payment_date) AS month,
        p.customer_id
    FROM
        payment p
),
active_customers_per_month AS (
    -- Count active customers per month
    SELECT
        year,
        month,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM
        monthly_activity
    GROUP BY
        year,
        month
)
SELECT
    acpm.year,
    acpm.month,
    acpm.active_customers,
    LAG(acpm.active_customers) OVER (ORDER BY acpm.year, acpm.month) AS prev_month_active_customers,
    ROUND(
        (acpm.active_customers - LAG(acpm.active_customers) OVER (ORDER BY acpm.year, acpm.month)) * 100.0 /
        NULLIF(LAG(acpm.active_customers) OVER (ORDER BY acpm.year, acpm.month), 0),
        2
    ) AS percentage_change
FROM
    active_customers_per_month acpm
ORDER BY
    acpm.year,
    acpm.month;
    
 -- 4.Retained customers every month.   
WITH monthly_customers AS (
    SELECT
        DATE_FORMAT(rental_date, '%Y-%m') AS month,
        customer_id
    FROM 
        rental
    GROUP BY 
        month, customer_id
),
monthly_active AS (
    SELECT
        month,
        COUNT(customer_id) AS active_customers
    FROM 
        monthly_customers
    GROUP BY 
        month
),
retained_customers AS (
    SELECT
        a.month,
        COUNT(a.customer_id) AS retained
    FROM 
        monthly_customers a
    INNER JOIN 
        monthly_customers b ON a.customer_id = b.customer_id AND DATE_FORMAT(DATE_ADD(STR_TO_DATE(a.month, '%Y-%m'), INTERVAL 1 MONTH), '%Y-%m') = b.month
    GROUP BY 
        a.month
)
SELECT 
    m.month, 
    m.active_customers,
    COALESCE(r.retained, 0) AS retained_customers
FROM 
    monthly_active m
LEFT JOIN 
    retained_customers r ON m.month = r.month
ORDER BY 
    m.month;