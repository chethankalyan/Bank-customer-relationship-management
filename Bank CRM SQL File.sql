use bank_crm;

ALTER TABLE customerinfo CHANGE COLUMN `Bank DOJ` bankdoj VARCHAR(255);
ALTER TABLE customerinfo MODIFY COLUMN bankdoj DATE;

UPDATE customerinfo
SET bankdoj = STR_TO_DATE(bankdoj, '%y-%m-%d')
WHERE STR_TO_DATE(bankdoj, '%d-%m-%Y') IS NOT NULL;

SET SQL_SAFE_UPDATES = 0;


-- 2)Identify the top 5 customers with the highest Estimated Salary 
--   in the last quarter of the year. (SQL)
select Customerid,
	   Surname,
       Estimatedsalary,
       dense_rank() over(order by estimatedsalary desc) as Ranks
from customerinfo
where quarter(bankdoj) in(4)  -- employee joined in last quarter 
order by estimatedsalary desc
limit 5;

-- 3) Calculate the average number of products 
-- used by customers who have a credit card. (SQL)

		select avg(numofproducts) as average_num_of_products
		from bank_churn
		where hascrcard=1;
select * from bank_churn;    

-- 5)Compare the average credit score of customers who have exited and those who remain.(SQL)

		select  ec.exitcategory,avg(bc.creditscore) as averagecreditscore
		from bank_churn bc join exitcustomer ec on bc.exited=ec.exitid
		group by ec.exitcategory;

-- 6) Which gender has a higher average estimated salary, 
--    and how does it relate to the number of active accounts? (SQL)

		select g.gendercategory,
			   sum(bc.isactivemember) as activecustomercount,
			   round(avg(co.estimatedsalary),1) as avgestimatedsalary
		from customerinfo co join gender g on co.genderid=g.genderid
		join bank_churn bc on co.customerid=bc.customerid
		group by g.gendercategory;

-- 7) Segment the customers based on their credit score and 
--    identify the segment with the highest exit rate. (SQL)
with distribution as (select CustomerId, exited,
						   case when CreditScore between 800 and 850 then 'Excellent'
								when CreditScore between 740 and 799 then 'Very Good'
								when CreditScore between 670 and 739 then 'Good'
								when CreditScore between 580 and 669 then 'Fair'
								else 'Poor' end as CreditScoreSegment
					from bank_churn),
distribution_2 as (select d.*,ec.exitcategory
                   from distribution d join exitcustomer ec on d.exited=ec.exitid)
SELECT CreditScoreSegment,
       sum(CASE WHEN exited = 1 THEN 1 ELSE 0 END)/count(*)*100 AS avg_exited_percentage
FROM distribution_2
GROUP BY CreditScoreSegment order by avg_exited_percentage desc;

-- 8) Find out which geographic region has the highest number of active customers 
--    with a tenure greater than 5 years. (SQL)

	select gp.geographylocation,count(*) as active_users_count
	from bank_churn bc join customerinfo ci on bc.customerid=ci.customerid
	join geography gp on ci.geographyid=gp.geographyid
	where bc.isactivemember=1
	and tenure >5
	group by gp.geographylocation;

-- 11) Examine the trend of customers joining over time and identify any seasonal patterns
--      (yearly or monthly). Prepare the data through SQL and then visualize it.

		select date_format(bankdoj,"%Y-%m") as joining_month,
			   count(*) as Customers_joined
		from customerinfo
		group by 1;
        
-- 15) Using SQL, write a query to find out the gender-wise average income of males and 
-- females in each geography id. Also, rank the gender according to the average value. (SQL)

with avggeographysalary as (select gp.geographylocation,
								   g.gendercategory,
								   round(avg(co.estimatedsalary)) as avg_salary
							from customerinfo co join gender g on co.genderid=g.genderid
							join geography gp on co.geographyid=gp.geographyid
							group by 1,2)
select *,dense_rank() over(partition by  GeographyLocation order by avg_salary DESC) as ranking
from avggeographysalary;

-- 16.	Using SQL, write a query to find out the average tenure of the people
--       who have exited in each age bracket (18-30, 30-50, 50+).
select case when c.age >=18 and c.age <30 then "adults"
            when c.age >=30 and c.age <=50 then "Middle age"
            when c.age >50 then "Old Aged" 
	   end as Age_category,
       avg(bc.tenure) as avg_tenure
from bank_churn bc join customerinfo c on bc.customerid=c.customerid
join exitcustomer e on bc.exited= e.exitid
where e.exitcategory="Exit"
group by 1;


-- 20) According to the age buckets find the number of customers who have a credit card.
-- Also retrieve those buckets that have lesser than average number of credit cards per bucket.

with CTE as (select case when c.age >=18 and c.age <30 then "adults"
            when c.age >=30 and c.age <=50 then "Middle age"
            when c.age >50 then "Old Aged" 
	   end as Age_category,
       count(*) as customer_count
from bank_churn bc join customerinfo c on bc.customerid=c.customerid
join exitcustomer e on bc.exited= e.exitid
where bc.hascrcard=1
group by 1)
select *
from CTE 
where customer_count<(select avg(customer_count) as avg_customer_count
                      from CTE);


-- 21)Rank the Locations as per the number of people who have churned the bank 
--    and average balance of the customers.

with CTE as (select gp.geographylocation,
				   count(*) as churned_count,
				   round(avg(bc.balance)) as avg_balance
			from bank_churn bc join customerinfo ci on bc.customerid=ci.customerid
			join geography gp on ci.geographyid=gp.geographyid
			where bc.exited=1
			group by gp.geographylocation)
select *,rank() over(order by churned_count desc,avg_balance desc) as churned_rank 
from CTE;


-- 23)Without using “Join”, can we get the “ExitCategory” from ExitCustomers table
--    to Bank_Churn table? If yes do this using SQL.

select CustomerId, CreditScore, Tenure, Balance,
       NumOfProducts, HasCrCard, IsActiveMember,
       case when Exited = 0 then 'Retain'
            else 'Exit'
	   end as ExitCategory
from  bank_churn;

-- 25) Write the query to get the customer IDs, their last name, and 
--   whether they are active or not for the customers whose surname ends with “on”.
select c.CustomerId, c.Surname, 
       case when b.IsActiveMember = 1 then 'Active'
			else 'Inactive'
       end as  ActivityStatus
from  customerinfo c
join bank_churn b on c.CustomerId = b.CustomerId
where c.Surname like '%on'
order by c.Surname;

-- 26) Can you observe any data disrupency in the Customer’s data? As a hint it’s present
--    in the IsActiveMember and Exited columns. One more point to consider is that 
--    the data in the Exited Column is absolutely correct and accurate.

select *
FROM bank_churn b join customerinfo c on b.CustomerId = c.CustomerId
WHERE b.Exited =1 and b.IsActiveMember =1;



-- Subjective questions:

-- 9) Utilize SQL queries to segment customers based on demographics and account details. 

SELECT g.GeographyLocation,
       CASE WHEN EstimatedSalary < 50000 THEN 'Low'
            WHEN EstimatedSalary < 100000 THEN 'Medium'
	        ELSE 'High' END AS IncomeSegment,
	   CASE WHEN c.GenderID = 1 THEN 'Male'
	   ELSE 'Female'
	   END AS Gender,Age,
        COUNT(c.CustomerId) AS NumberOfCustomers
FROM customerinfo c
JOIN geography g ON c.GeographyID = g.GeographyID
GROUP BY IncomeSegment, g.GeographyLocation, Gender, Age
ORDER BY g.GeographyLocation, Age;

-- 14)In the “Bank_Churn” table how can you modify the name of the  
--     “HasCrCard” column to “Has_creditcard”?

alter table bank_churn
rename column HasCrcard to Has_CreditCard;

-- other KPIs

with CTE as (select CustomerId, exited,
	   case when CreditScore between 800 and 850 then 'Excellent'
		    when CreditScore between 740 and 799 then 'Very Good'
			when CreditScore between 670 and 739 then 'Good'
			when CreditScore between 580 and 669 then 'Fair'
	   else 'Poor' end as CreditScoreSegment
from bank_churn),
CTE_2 as (select creditscoresegment,
			     sum(case when exited =1 then 1 else 0 end)as exit_count,
			     count(*) as total_customers
		  from CTE
		  group by creditscoresegment)
select *,(exit_count/total_customers)*100 as exit_rate
from CTE_2;


