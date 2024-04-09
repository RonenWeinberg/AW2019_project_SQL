-- Project 2 - SQL Data Analysis

--1
SELECT ProductID, Name, Color, ListPrice, Size
FROM Production.Product
EXCEPT
SELECT P.ProductID, P.Name, P.Color, P.ListPrice, P.Size
FROM Sales.SalesOrderDetail AS sod JOIN Sales.SpecialOfferProduct AS sop
	ON sod.ProductID = sop.ProductID
	JOIN Production.Product AS p
	ON sop.ProductID = p.ProductID


--2

/*
הערה: טבלת התוצאה שמוצגת בטופס מבוססת על קישור לא נכון
c.CustomerID = p.BusinessEntityID
הקישור הנכון לפי 
ERD
צריך להיות
c.PersonID = p.BusinessEntityID
מצורפות למטה שאילתות בשתי הגרסאות
*/
--A
SELECT c.CustomerID,
	   ISNULL(p.LastName, 'Unknown') AS LastName,
	   ISNULL(p.FirstName, 'Unknown') AS FirstName
FROM Sales.Customer AS c LEFT JOIN Person.Person As p
	ON c.CustomerID = p.BusinessEntityID
EXCEPT
SELECT soh.CustomerID,
	   ISNULL(p.LastName, 'Unknown') AS LastName,
	   ISNULL(p.FirstName, 'Unknown') AS FirstName
FROM Sales.SalesOrderHeader AS soh JOIN Sales.Customer AS c
	ON soh.CustomerID = c.CustomerID
	LEFT JOIN Person.Person AS p
	ON c.CustomerID = p.BusinessEntityID
ORDER BY c.CustomerID

--B
SELECT c.CustomerID,
	   ISNULL(p.LastName, 'Unknown') AS LastName,
	   ISNULL(p.FirstName, 'Unknown') AS FirstName
FROM Sales.Customer AS c LEFT JOIN Person.Person As p
	ON c.PersonID = p.BusinessEntityID
EXCEPT
SELECT soh.CustomerID,
	   ISNULL(p.LastName, 'Unknown') AS LastName,
	   ISNULL(p.FirstName, 'Unknown') AS FirstName
FROM Sales.SalesOrderHeader AS soh JOIN Sales.Customer AS c
	ON soh.CustomerID = c.CustomerID
	LEFT JOIN Person.Person AS p
	ON c.PersonID = p.BusinessEntityID
ORDER BY c.CustomerID


--3
SELECT TOP 10 soh.CustomerID,
			  p.FirstName,
			  p.LastName,
			  COUNT(*) AS CountOfOrders
FROM Sales.SalesOrderHeader AS soh JOIN Sales.Customer AS c
	ON soh.CustomerID = c.CustomerID
	JOIN Person.Person AS p
	ON c.PersonID = p.BusinessEntityID
GROUP BY soh.CustomerID, p.FirstName, p.LastName
ORDER BY CountOfOrders DESC, soh.CustomerID


--4
SELECT p.FirstName,
	   p.LastName, 
	   e.JobTitle,
	   e.HireDate,
	   COUNT(*) OVER (PARTITION BY e.JobTitle) AS CountOfTitle
FROM HumanResources.Employee AS e JOIN Person.Person AS p
	ON e.BusinessEntityID = p.BusinessEntityID
ORDER BY e.JobTitle


--5
SELECT SalesOrderID, CustomerID, LastName, FirstName, LastOrder, PreviousOrder
FROM (
	SELECT soh.SalesOrderID, c.CustomerID, p.LastName, p.FirstName,
		   soh.OrderDate AS LastOrder,
		   LAG(soh.OrderDate) OVER (PARTITION BY c.CustomerID 
									ORDER BY soh.OrderDate) AS PreviousOrder,
		   ROW_NUMBER() OVER (PARTITION BY c.CustomerID 
							  ORDER BY soh.OrderDate DESC) AS RN
	FROM Sales.Customer AS c JOIN Sales.SalesOrderHeader AS soh
		ON c.CustomerID = soh.CustomerID
		JOIN Person.Person AS p
		ON c.PersonID = p.BusinessEntityID) x
WHERE RN=1
ORDER BY LastName


--6
WITH TotalOrderSum
AS (
	SELECT SalesOrderID, 
		   SUM(UnitPrice*(1- UnitPriceDiscount)* OrderQty) AS Total
	FROM Sales.SalesOrderDetail
	GROUP BY SalesOrderID) 

SELECT Year, SalesOrderID, LastName, FirstName, Total
FROM (
	SELECT YEAR(soh.OrderDate) AS Year,
		   tos.SalesOrderID,
		   p.LastName,
		   p.FirstName,
		   FORMAT(tos.Total, '#,#.0') AS Total,
		   RANK() OVER (PARTITION BY YEAR(soh.OrderDate)
							  ORDER BY tos.total DESC) AS RNK
	FROM TotalOrderSum AS tos JOIN Sales.SalesOrderHeader AS soh
		ON tos.SalesOrderID = soh.SalesOrderID
		JOIN Sales.Customer AS c
		ON soh.CustomerID = c.CustomerID
		JOIN Person.Person AS p
		ON c.PersonID = p.BusinessEntityID) x
WHERE RNK = 1


--7
SELECT Month, 
	   ISNULL([2011], 0) [2011],
	   [2012],
	   [2013],
	   ISNULL([2014], 0) [2014]
FROM (
	SELECT YEAR(OrderDate) AS Year, MONTH(OrderDate) AS Month, 
		   COUNT(*) AS NumOfOrders
	FROM Sales.SalesOrderHeader
	GROUP BY YEAR(OrderDate), MONTH(OrderDate)) x
PIVOT (SUM(NumOfOrders) FOR Year IN ([2011], [2012], [2013], [2014])) AS pvt


--8

WITH SumMonth
AS (
	SELECT YEAR(soh.OrderDate) AS Year,
		   MONTH(soh.OrderDate) AS Month,
		   SUM(sod.UnitPrice*(1-sod.UnitPriceDiscount)) AS Sum_Price
	FROM Sales.SalesOrderDetail AS sod JOIN Sales.SalesOrderHeader AS soh
		ON sod.SalesOrderID = soh.SalesOrderID
	GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate))


SELECT Year,
		CONVERT(CHAR, Month) AS Month,
		ROUND(Sum_Price, 2) AS Sum_Price,
		ROUND(SUM(Sum_Price) OVER (PARTITION BY YEAR
							ORDER BY MONTH
							ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
				2) AS CumSum
FROM SumMonth
UNION
SELECT Year,
	  'Grand Total',
	  NULL,
	  ROUND(SUM(Sum_Price), 2)
FROM SumMonth
GROUP BY Year
ORDER BY Year, CumSum

--9
WITH employees_list
AS (
	SELECT d.Name AS DepartmentName,
		   e.BusinessEntityID AS [Employee'sID],
		   p.FirstName+' '+p.LastName AS [Employee'sFullName],
		   e.HireDate,
		   DATEDIFF(MONTH, e.HireDate, GETDATE()) AS Seniority
	FROM HumanResources.Employee AS e JOIN Person.Person AS p
		ON e.BusinessEntityID = p.BusinessEntityID
		JOIN HumanResources.EmployeeDepartmentHistory AS edh
		ON e.BusinessEntityID = edh.BusinessEntityID
		JOIN HumanResources.Department AS d
		ON edh.DepartmentID = d.DepartmentID)

SELECT *,
		DATEDIFF(DAY, PreviousEmpHDate, HireDate) AS DiffDays
FROM (
	SELECT *,
		LAG([Employee'sFullName]) OVER (PARTITION BY DepartmentName
										ORDER BY HireDate) AS PreviousEmpName,
		LAG(HireDate) OVER (PARTITION BY DepartmentName
							ORDER BY HireDate) AS PreviousEmpHDate
	FROM employees_list) x
ORDER BY DepartmentName, HireDate DESC


--10
SELECT HireDate, DepartmentID,
	STRING_AGG (CONCAT(BusinessEntityID,' ', [Employee'sFullName]), ', ')
				WITHIN GROUP (ORDER BY [Employee'sFullName]) AS TeamEmployees
FROM (
	SELECT e.HireDate, edh.DepartmentID, e.BusinessEntityID,
		   p.LastName+' '+p.FirstName AS [Employee'sFullName]
	FROM HumanResources.Employee AS e JOIN Person.Person AS p
		ON e.BusinessEntityID = p.BusinessEntityID
		JOIN HumanResources.EmployeeDepartmentHistory AS edh
		ON e.BusinessEntityID = edh.BusinessEntityID
	WHERE edh.EndDate IS NULL) x
GROUP BY HireDate, DepartmentID
ORDER BY HireDate DESC




