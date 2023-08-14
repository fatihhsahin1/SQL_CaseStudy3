--1.Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.
--Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!
SELECT 
    s.customer_id,
    s.plan_id,
    p.plan_name,
    s.start_date
FROM 
    foodie_fi.dbo.subscriptions AS s
JOIN 
   foodie_fi.dbo.plans AS p ON s.plan_id = p.plan_id
WHERE s.customer_id<=8
ORDER BY 
    s.customer_id, 
    s.start_date;
	
--2.How many customers has Foodie-Fi ever had?
SELECT 
    COUNT(DISTINCT customer_id) AS total_customers 
FROM 
    foodie_fi.dbo.subscriptions;

--3.What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
SELECT 
    DATEPART(YEAR, start_date) AS year,
    DATEPART(MONTH, start_date) AS month,
    COUNT(*) AS trial_starts
FROM 
    foodie_fi.dbo.subscriptions
WHERE 
    plan_id = 0
GROUP BY 
    DATEPART(YEAR, start_date), 
    DATEPART(MONTH, start_date)
ORDER BY 
    year, 
    month;
--4.What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
SELECT 
	p.plan_name, COUNT(*) AS event_count
FROM  
	foodie_fi.dbo.plans p
JOIN  
	foodie_fi.dbo.subscriptions s ON s.plan_id = p.plan_id
WHERE
	DATEPART(year, s.start_date)>2020
GROUP BY 
	plan_name;


--5.What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

WITH CustomerCounts AS (
    SELECT 
        COUNT(DISTINCT customer_id) AS TotalCustomers,
        COUNT(DISTINCT CASE WHEN plan_id = 4 THEN customer_id END) AS ChurnedCustomers
    FROM foodie_fi.dbo.subscriptions
)

SELECT 
    TotalCustomers,
    ChurnedCustomers,
    ROUND(CAST(ChurnedCustomers AS FLOAT) / CAST(TotalCustomers AS FLOAT) * 100, 1) AS ChurnedPercentage
FROM CustomerCounts;


--6.How many customers have churned straight after their initial free trial? -what percentage is this rounded to the nearest whole number?

WITH TrialCustomers AS (
    SELECT customer_id, MIN(start_date) AS TrialStartDate
    FROM foodie_fi.dbo.subscriptions
    WHERE plan_id = 0
    GROUP BY customer_id
)


, ChurnedAfterTrial AS (
    SELECT 
        tc.customer_id,
        MIN(s.start_date) AS NextStartDate
    FROM foodie_fi.dbo.subscriptions s
    JOIN TrialCustomers tc ON s.customer_id = tc.customer_id
    WHERE s.start_date > tc.TrialStartDate
    GROUP BY tc.customer_id
    HAVING MIN(s.plan_id) = 4
)

SELECT 
    COUNT(*) AS ChurnedCustomersCount,
    ROUND(CAST(COUNT(*) AS FLOAT) / (SELECT COUNT(*) FROM TrialCustomers) * 100, 1) AS ChurnedPercentage
FROM ChurnedAfterTrial;


--7.What is the number and percentage of customer plans after their initial free trial?

WITH TrialCustomers AS (
    SELECT customer_id, MIN(start_date) AS TrialStartDate
    FROM foodie_fi.dbo.subscriptions
    WHERE plan_id = 0
    GROUP BY customer_id
)

 ,PostTrialPlans AS (
    SELECT 
        s.plan_id,
        p.plan_name,
        COUNT(DISTINCT s.customer_id) AS CustomerCount
    FROM foodie_fi.dbo.subscriptions s
    JOIN TrialCustomers tc ON s.customer_id = tc.customer_id
    JOIN foodie_fi.dbo.plans p ON s.plan_id = p.plan_id
    WHERE s.start_date > tc.TrialStartDate
    GROUP BY s.plan_id, p.plan_name
)

SELECT 
    plan_id,
    plan_name,
    CustomerCount,
    ROUND(CAST(CustomerCount AS FLOAT) / (SELECT SUM(CustomerCount) FROM PostTrialPlans) * 100, 1) AS PlanPercentage
FROM PostTrialPlans
ORDER BY plan_id;

--8.What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

WITH LatestPlan AS (
    SELECT 
        customer_id, 
        plan_id,
        ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date DESC) AS rn
    FROM foodie_fi.dbo.subscriptions
    WHERE start_date <= '2020-12-31'
)

, PlanCounts AS (
    SELECT 
        plan_id, 
        COUNT(DISTINCT customer_id) AS CustomerCount
    FROM LatestPlan
    WHERE rn = 1
    GROUP BY plan_id
)

SELECT 
    p.plan_id,
    p.plan_name,
    pc.CustomerCount,
    ROUND(CAST(pc.CustomerCount AS FLOAT) / (SELECT SUM(CustomerCount) FROM PlanCounts) * 100, 1) AS PlanPercentage
FROM foodie_fi.dbo.plans p
LEFT JOIN PlanCounts pc ON p.plan_id = pc.plan_id
ORDER BY p.plan_id;


--9.How many customers have upgraded to an annual plan in 2020?
SELECT 
    COUNT(DISTINCT customer_id) AS NumberOfCustomersUpgraded
FROM foodie_fi.dbo.subscriptions
WHERE plan_id = 3 
AND YEAR(start_date) = 2020;

--10.How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH JoinDates AS (
    SELECT 
        customer_id, 
        MIN(start_date) AS JoinDate
    FROM foodie_fi.dbo.subscriptions
    GROUP BY customer_id
)

, UpgradeDates AS (
    SELECT 
        customer_id, 
        MIN(start_date) AS UpgradeToDate
    FROM foodie_fi.dbo.subscriptions
    WHERE plan_id = 3
    GROUP BY customer_id
)

SELECT 
    AVG(DATEDIFF(DAY, j.JoinDate, u.UpgradeToDate)) AS AverageDaysToUpgrade
FROM JoinDates j
JOIN UpgradeDates u ON j.customer_id = u.customer_id;

--11.Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH JoinDates AS (
    -- Find the date each customer joined Foodie-Fi
    SELECT 
        customer_id, 
        MIN(start_date) AS JoinDate
    FROM foodie_fi.dbo.subscriptions
    GROUP BY customer_id
)

, UpgradeDates AS (
    -- Find the date each customer upgraded to the annual plan
    SELECT 
        customer_id, 
        MIN(start_date) AS UpgradeToDate
    FROM foodie_fi.dbo.subscriptions
    WHERE plan_id = 3
    GROUP BY customer_id
)

, DaysToUpgrade AS (
    -- Calculate the difference in days for each customer
    SELECT 
        j.customer_id,
        DATEDIFF(DAY, j.JoinDate, u.UpgradeToDate) AS DaysTaken
    FROM JoinDates j
    JOIN UpgradeDates u ON j.customer_id = u.customer_id
)

-- Bucket the days taken into 30-day periods and count the number of customers in each bucket
SELECT 
    CASE 
        WHEN DaysTaken BETWEEN 0 AND 30 THEN '0-30 days'
        WHEN DaysTaken BETWEEN 31 AND 60 THEN '31-60 days'
        WHEN DaysTaken BETWEEN 61 AND 90 THEN '61-90 days'
        ELSE '91+ days'
    END AS TimePeriod,
    COUNT(customer_id) AS NumberOfCustomers,
    AVG(DaysTaken) AS AverageDaysTaken
FROM DaysToUpgrade
GROUP BY 
    CASE 
        WHEN DaysTaken BETWEEN 0 AND 30 THEN '0-30 days'
        WHEN DaysTaken BETWEEN 31 AND 60 THEN '31-60 days'
        WHEN DaysTaken BETWEEN 61 AND 90 THEN '61-90 days'
        ELSE '91+ days'
    END
ORDER BY 
    CASE 
        WHEN 
            CASE 
                WHEN DaysTaken BETWEEN 0 AND 30 THEN '0-30 days'
                WHEN DaysTaken BETWEEN 31 AND 60 THEN '31-60 days'
                WHEN DaysTaken BETWEEN 61 AND 90 THEN '61-90 days'
                ELSE '91+ days'
            END = '0-30 days' THEN 1
        WHEN 
            CASE 
                WHEN DaysTaken BETWEEN 0 AND 30 THEN '0-30 days'
                WHEN DaysTaken BETWEEN 31 AND 60 THEN '31-60 days'
                WHEN DaysTaken BETWEEN 61 AND 90 THEN '61-90 days'
                ELSE '91+ days'
            END = '31-60 days' THEN 2
        WHEN 
            CASE 
                WHEN DaysTaken BETWEEN 0 AND 30 THEN '0-30 days'
                WHEN DaysTaken BETWEEN 31 AND 60 THEN '31-60 days'
                WHEN DaysTaken BETWEEN 61 AND 90 THEN '61-90 days'
                ELSE '91+ days'
            END = '61-90 days' THEN 3
        ELSE 4
    END;


--12.How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
WITH ProMonthlyCustomers AS (
    -- Find customers who were on the pro monthly plan in 2020
    SELECT 
        customer_id, 
        start_date AS ProStartDate
    FROM foodie_fi.dbo.subscriptions
    WHERE plan_id = 2 AND YEAR(start_date) = 2020
)

SELECT 
    COUNT(DISTINCT p.customer_id) AS NumberOfDowngrades
FROM ProMonthlyCustomers p
JOIN foodie_fi.dbo.subscriptions s
ON p.customer_id = s.customer_id
WHERE s.plan_id = 1 -- basic monthly plan
AND YEAR(s.start_date) = 2020
AND s.start_date > p.ProStartDate; -- ensure the basic monthly plan started after the pro monthly plan

--C. Challenge Payment Question
/*The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:

monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
once a customer churns they will no longer make payments
*/
WITH MonthlyPayments AS (
    SELECT 
        customer_id,
        plan_id,
        CASE 
            WHEN plan_id = 1 THEN 'basic monthly'
            WHEN plan_id = 2 THEN 'pro monthly'
        END AS plan_name,
        DATEADD(MONTH, ROW_NUMBER() OVER (PARTITION BY customer_id, plan_id ORDER BY start_date) - 1, start_date) AS payment_date,
        CASE
            WHEN plan_id = 1 THEN 9.90
            WHEN plan_id = 2 THEN 19.90
        END AS amount,
        ROW_NUMBER() OVER (PARTITION BY customer_id, plan_id ORDER BY start_date) AS payment_order
    FROM foodie_fi.dbo.subscriptions
    WHERE plan_id IN (1, 2) -- Monthly plans
    AND YEAR(start_date) = 2020
    AND customer_id NOT IN (
        SELECT customer_id
        FROM foodie_fi.dbo.subscriptions
        WHERE plan_id = 4 AND YEAR(start_date) = 2020
    )
)
SELECT * FROM MonthlyPayments;
