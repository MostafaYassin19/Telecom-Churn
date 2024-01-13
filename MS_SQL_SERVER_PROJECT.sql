USE GP
GO 
-- Number of churns per chrun caregory
SELECT churcat.Churn_Category ,COUNT(Customer_ID) [Total number of churns]
FROM Customer cus INNER JOIN Churn_Reason churea
ON cus.Churn_reason_ID = churea.Churn_Reason_ID
INNER JOIN Churn_Category churcat 
ON churea.Churn_Category_ID = churcat.Churn_Category_ID
GROUP BY churcat.Churn_Category 

GO
--3. the churn rate by agent
SELECT cal.Agent,
ROUND(CAST(COUNT(cust.Customer_ID ) AS float)/(SELECT COUNT(cust1.Customer_ID) 
												FROM Customer cust1, call cal1
												WHERE cal1.Customer_Id = cust1.Customer_ID AND cal.Agent = cal1.Agent
												GROUP BY cal1.Agent), 3)*100 [Churn Rate]
FROM Customer cust, call cal
WHERE cal.Customer_Id = cust.Customer_ID AND cust.Churn_reason_ID IN (SELECT Churn_reason_ID FROM Churn_Reason)
GROUP BY cal.Agent

GO
--11 set categories or classes for customers based on how many seviceses they use, starting from class A (highest number of serviceses) to class D (lowest)
CREATE VIEW customer_class AS
SELECT Customer_ID, NUMBER_OF_SERVICES,
CASE 
	WHEN NUMBER_OF_SERVICES > 6 THEN 'A'
	WHEN NUMBER_OF_SERVICES > 4 AND NUMBER_OF_SERVICES <=6 THEN 'B'
	WHEN NUMBER_OF_SERVICES > 2 AND NUMBER_OF_SERVICES <=4 THEN 'C'
	WHEN NUMBER_OF_SERVICES > 0 AND NUMBER_OF_SERVICES <=2 THEN 'D'
	WHEN NUMBER_OF_SERVICES = 0 THEN 'Z'
END AS CLASS
FROM (SELECT cust.Customer_ID,
CAST(custint.Premium_TSupport AS int)+CAST(custint.Online_Backup AS int)+CAST(custint.Online_Security AS int)+CAST(custint.Premium_TSupport AS int)+
CAST(custint.Streaming_Movies AS int)+CAST(custint.Streaming_Music AS int)+CAST(custint.Streaming_TV AS int)+CAST(custint.Unlimited_Data AS int) AS NUMBER_OF_SERVICES
FROM Customer cust, Customer_Internet custint
WHERE cust.Customer_ID = custint.Customer_ID) a

GO
--5 number of customers per services
SELECT 
SUM(CAST(Premium_TSupport AS int)) Premium_TSupport,  SUM(CAST(Online_Backup AS int)) Online_Backup,SUM(CAST(Online_Security AS int)) Online_Security,
SUM(CAST(Streaming_Movies AS int)) Streaming_Movies,+SUM(CAST(Streaming_Music AS int)) Streaming_Music,SUM(CAST(Streaming_TV AS int)) Streaming_TV,
SUM(CAST(Unlimited_Data AS int)) Unlimited_Data
FROM Customer_Internet


go
--number of churn by offer.

SELECT  c.Offer,COUNT(c.Customer_ID) as NumberCusomerChurn ,AVG(c.Churn_Score) as Avg_churn_score
	from Customer c INNER JOIN Churn_Reason  cr
	ON cr.Churn_Reason_ID=c.Churn_reason_ID 
	GROUP BY c.Offer

go

--number of population, customers, , Customer Number,churn Number for city.
CREATE or alter VIEW  city_states AS
SELECT City,sum(Population_Num) as PopNum,cast( COUNT(Customer_ID) as float) as CustNum ,
		isnull((select COUNT(c1.Customer_ID) 
		from Customer c1 ,Location l1 
		WHERE c1.Location_ID=l1.Location_ID and l1.City=l.city AND c1.Status_ID=3
		GROUP by l1.City),0) as ChurnNum
from Customer INNER join Location l on Customer.Location_ID=l.Location_ID
INNER JOIN Population on l.Zipcode =Zipcode_ID
GROUP by City

go

--ranking agents based on Average satisfaction rating

SELECT c.Agent, ROUND(AVG(CAST(c.Satisfaction_rating AS float)), 3)  Satisfaction_Rating
FROM Call c
GROUP BY c.Agent
ORDER BY Satisfaction_Rating DESC --AVG(c.Satisfaction_rating) DESC

go

--7ranking payement methods based on total revenue

SELECT c.Payment_Method ,SUM(c.Total_Revenue) AS 'Total Revenue'
FROM Customer c
GROUP BY c.Payment_Method
ORDER BY SUM(c.Total_Revenue) DESC

go

--2ranking cities based total revenue , phoneservice charges,internet monthly GB
SELECT L.City,SUM(c.Total_Revenue)AS'Total Revenue',SUM(ps.Total_Long_Distance_Charges) AS'Phone Service Total Charges'
,SUM(ci.Avg_Monthly_GB)as'AvgMonthly GB'
FROM Customer c,Customer_Internet ci,Phone_Service ps,Location l
WHERE L.Location_ID=c.Location_ID AND c.Customer_ID=ci.Customer_ID AND c.Customer_ID=ps.Customer_ID
GROUP BY L.City

go

--8ranking contract based on number of customers
SELECT c.Contract_Type,COUNT(c1.Customer_ID)AS 'NumOfCustomers'
FROM Contract c,Customer c1
WHERE c.Contract_ID=c1.Contract_ID
GROUP BY c.Contract_Type

go

--9top calls topics
SELECT c.Topic ,COUNT(c.Call_ID) AS NumOfCalls
FROM Call c
GROUP BY c.Topic
ORDER by NumOfCalls desc

go

--6 total calls,problem solved,num of droped calls by agent,(proc)
CREATE PROC agent @ag VARCHAR(50)
AS
SELECT  c.Agent,SUM(CAST(c.Resolved AS INT)) AS'problems solved',SUM(CAST(c.Answered AS INT)) AS 'NumOfCalls'
FROM Call c
WHERE c.Agent=@ag
GROUP BY c.Agent

go
agent'Diane'
	--Trigger on customer table if any update done record at in audit table
CREATE TABLE [dbo].[Customer_Audit](
	[Customer_ID] [int] NULL,
	[ColumnName] [varchar](50) NULL,
	[OldValue] [varchar](max) NULL,
	[NewValue] [varchar](max) NULL,
	[UpdatedBy] [varchar](500) NULL,
	[UpdatedAt] [datetime] NULL)


go


CREATE OR alter TRIGGER CustomerTable_Audit
ON [dbo].[Customer]
AFTER UPDATE
AS
BEGIN
    DECLARE @customerID INT, @oldStatusID INT, @newStatusID INT, @oldContractID INT, @newContractID INT;

    SELECT 
        @customerID = Customer_ID,
        @newStatusID = Status_ID,
        @newContractID = Contract_ID
	FROM inserted
	SELECT 
		@oldStatusID = Status_ID,
		@oldcontractID = Contract_ID
	FROM deleted
    IF @customerID IS NOT NULL
    BEGIN
        
        IF UPDATE(Status_ID)
        BEGIN
            INSERT INTO [dbo].[Customer_Audit] (Customer_ID, ColumnName, OldValue, NewValue, UpdatedBy, UpdatedAt)
            VALUES (@customerID, 'Status_ID', @oldStatusID , @newStatusID , SUSER_SNAME(), GETDATE());
        END

        IF UPDATE(Contract_ID)
        BEGIN
            INSERT INTO [dbo].[Customer_Audit] (Customer_ID, ColumnName, OldValue, NewValue, UpdatedBy, UpdatedAt)
            VALUES (@customerID, 'Contract_ID', @oldContractID , @newContractID , SUSER_SNAME(), GETDATE());
        END
    END
END

---	Total Number customer and average duration joined for all internet type
SELECT I.Internet_Type,count(c.Customer_ID) as CustNum,avg(c.Tenure_In_Months)as avgDuration
from Customer c,Customer_Internet ci,Internet_Service I
where c.Customer_ID=ci.Customer_ID and i.Internet_Service_ID=ci.Internet_Service_ID 
GROUP BY I.Internet_Type
ORDER by CustNum desc



