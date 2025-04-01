/* Maven Telecom Churn Analysis */

--1. Check for duplicates
SELECT [Customer ID], COUNT(*) AS occurrences
FROM [dbo].[telecom_customer_churn]
GROUP BY [Customer ID]
HAVING COUNT(*) > 1;

--2. How many Customers do we have currently?
SELECT COUNT(DISTINCT([Customer ID]))
FROM [dbo].[telecom_customer_churn]


--3. How many customers joined the company during the last quarter?
WITH LastQuarter AS (
		SELECT DATEADD(MONTH, -3, GETDATE()) AS "StartofLastQuarter"
		)
SELECT COUNT(*) AS customer_joined_last_quarter
 -- JOINED DATE
FROM [dbo].[telecom_customer_churn]
WHERE DATEADD(MONTH, -[Tenure in Months], GETDATE()) >= 
			(SELECT StartofLastQuarter 
		 FROM LastQuarter);

--4. What is the customer profile for a customer that churned, joined, and stayed? Are they different?
WITH CustomerProfile AS (
    SELECT Gender, Age, Married, [Number of Dependents], [Customer Status],
           ROW_NUMBER() OVER (PARTITION BY [Customer Status] ORDER BY Age) AS RowNum
    FROM telecom_customer_churn
)
SELECT [Customer Status], Gender, Married, 
       AVG(CAST ([Age] AS INT)) AS Avg_Age, 
       AVG(CAST ([Number of Dependents] AS INT)) AS Avg_Dependents,
       COUNT(*) AS Total_Customers
FROM CustomerProfile
GROUP BY [Customer Status], Gender, Married
ORDER BY [Customer Status];


--5. What are the key drivers for churn
SELECT [Churn Category], [Churn Reason], COUNT(*) AS customers
FROM [dbo].[telecom_customer_churn]
WHERE [Customer Status] = 'Churned'
GROUP BY [Churn Category], [Churn Reason]
ORDER BY COUNT(*) DESC;

--6. What Contract are Churners on?
SELECT [Contract]
		,COUNT(*) AS customers
		,ROUND(( COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () ), 1)   AS per
FROM [dbo].[telecom_customer_churn]
WHERE [Customer Status] = 'Churned'
GROUP BY [Contract]
ORDER BY COUNT(*) DESC;


--7. Do Churners have access to Premium Tech Support?
SELECT [Premium Tech Support], count(*) AS customers
, ROUND(( COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () ), 1)   AS per
FROM [dbo].[telecom_customer_churn]
WHERE [Customer Status] = 'Churned'
GROUP BY [Premium Tech Support] 
ORDER BY COUNT(*) DESC;

---8. What Internet Type do Churned Customers use?
SELECT [Internet Type], count(*) AS customers
, ROUND(( COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () ), 1)   AS per
FROM [dbo].[telecom_customer_churn]
WHERE [Customer Status] = 'Churned'
GROUP BY [Internet Type]
ORDER BY COUNT(*) DESC;

---9. What Offers are Churned Customers on?
SELECT [Offer], count(*) AS customers
, ROUND(( COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () ), 1)   AS per
FROM [dbo].[telecom_customer_churn]
WHERE [Customer Status] = 'Churned'
GROUP BY [Offer]
ORDER BY COUNT(*) DESC;

--10. Risk Level of Customers
SELECT [Customer ID]
	,[Offer]
	,[Premium Tech Support]
	,[Contract]
	,[Internet Type] 
	,CASE
		WHEN(
			CASE WHEN [Offer] = 'None' THEN 1 ELSE 0 END +
			CASE WHEN [Premium Tech Support] = 'No' THEN 1 ELSE 0 END +
			CASE WHEN [Contract] = 'Month-to-Month' THEN 1 ELSE 0 END +
			CASE WHEN [Internet Type] = 'Fiber Optic' THEN 1 ELSE 0 END) 
			>=3 THEN 'High Risk'
		WHEN(
			CASE WHEN [Offer] = 'None' THEN 1 ELSE 0 END +
			CASE WHEN [Premium Tech Support] = 'No' THEN 1 ELSE 0 END +
			CASE WHEN [Contract] = 'Month-to-Month' THEN 1 ELSE 0 END +
			CASE WHEN [Internet Type] = 'Fiber Optic' THEN 1 ELSE 0 END) 
			=2 THEN 'Medium Risk'
		ELSE 'Low Risk'
	END AS "Risk Level"
FROM [dbo].[telecom_customer_churn]
WHERE [Customer Status] != 'Churned' 


---11. Risk Level and Value of Customers
SELECT [Customer ID]
	,[Number of Referrals]
	,[Monthly Charge]
	,[Tenure in Months] 
	,CASE 
		WHEN [Number of Referrals] > 0 
		AND [Monthly Charge] >= (SELECT TOP (1) PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY [Monthly Charge]) OVER () 
	FROM [dbo].[telecom_customer_churn])
		AND [Tenure in Months] > 9  
		THEN 'High Value'
		WHEN [Tenure in Months] > 9
		THEN 'Medium Value'
		ELSE 'Low Value'
	END AS "CustomerValue"
	,CASE
		WHEN(
			CASE WHEN [Offer] = 'None' THEN 1 ELSE 0 END +
			CASE WHEN [Premium Tech Support] = 'No' THEN 1 ELSE 0 END +
			CASE WHEN [Contract] = 'Month-to-Month' THEN 1 ELSE 0 END +
			CASE WHEN [Internet Type] = 'Fiber Optic' THEN 1 ELSE 0 END) 
			>=3 THEN 'High Risk'
		WHEN(
			CASE WHEN [Offer] = 'None' THEN 1 ELSE 0 END +
			CASE WHEN [Premium Tech Support] = 'No' THEN 1 ELSE 0 END +
			CASE WHEN [Contract] = 'Month-to-Month' THEN 1 ELSE 0 END +
			CASE WHEN [Internet Type] = 'Fiber Optic' THEN 1 ELSE 0 END) 
			=2 THEN 'Medium Risk'
		ELSE 'Low Risk'
	END AS "Risk Level"
		
FROM [dbo].[telecom_customer_churn]


--12.High value customers at risk of churning?
WITH CustomerClassification AS (
    SELECT 
        [Customer ID], 
        [Tenure in Months], 
        [Monthly Charge], 
		[Number of Referrals],
		[Customer Status],
        -- Calculate the 50th percentile of MonthlyCharge
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST([Monthly Charge] AS DECIMAL)) OVER () AS MedianMonthlyCharge
    ,[Premium Tech Support],
	[Internet Type],
	[Offer],
	[Contract] 
	, -- Classify customers based on the number of risk indicators
    CASE
        WHEN 
            (CASE 
                WHEN [Premium Tech Support] = 'No' THEN 1 ELSE 0 END +
                CASE WHEN [Internet Type] = 'Fiber Optic' THEN 1 ELSE 0 END +
                CASE WHEN [Offer] = 'None' THEN 1 ELSE 0 END +
                CASE WHEN [Contract] = 'Month-to-Month' THEN 1 ELSE 0 END
            ) >= 3 THEN 'High Risk'
        WHEN 
            (CASE 
                WHEN [Premium Tech Support] = 'No' THEN 1 ELSE 0 END +
                CASE WHEN [Internet Type] = 'Fiber Optic' THEN 1 ELSE 0 END +
                CASE WHEN [Offer] = 'None' THEN 1 ELSE 0 END +
                CASE WHEN [Contract] = 'Month-to-Month' THEN 1 ELSE 0 END
            ) = 2 THEN 'Medium Risk'
        WHEN 
            (CASE 
                WHEN [Premium Tech Support] = 'No' THEN 1 ELSE 0 END +
                CASE WHEN [Internet Type] = 'Fiber Optic' THEN 1 ELSE 0 END +
                CASE WHEN [Offer] = 'None' THEN 1 ELSE 0 END +
                CASE WHEN [Contract] = 'Month-to-Month' THEN 1 ELSE 0 END
            ) = 1 THEN 'Low Risk'
        ELSE 'Low Risk'
    END AS "CustomerRiskLevel"

	FROM
        [dbo].[telecom_customer_churn]
)
SELECT 
    [Customer ID],
	[Tenure in Months],
	[Monthly Charge],
	 [Number of Referrals],
	[Customer Status],
    CASE
        -- High: Must satisfy both condition 1 and condition 2
        WHEN [Tenure in Months] >= 9 AND [Monthly Charge] >= MedianMonthlyCharge AND [Number of Referrals] > 0 THEN 'High'
        WHEN [Tenure in Months] >= 9 AND [Monthly Charge] >= MedianMonthlyCharge THEN 'High'
        
        -- Medium: Must satisfy at least condition 1
        WHEN [Tenure in Months] >= 9 THEN 'Medium'
        
        -- Low: Doesn't satisfy any of the conditions
        ELSE 'Low'
    END AS "CustomerValue"
	,[Premium Tech Support],
	[Internet Type],
	[Offer],
	[Contract]
	,CustomerRiskLevel
FROM 
    CustomerClassification
WHERE CustomerRiskLevel = 'High Risk' AND [Customer Status] != 'Churned'
ORDER BY CustomerValue ASC;