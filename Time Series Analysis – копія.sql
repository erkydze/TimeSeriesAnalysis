/*Question1. Which products have the highest sales volume in the past year?*/
SELECT Product_name,  
       sum(Sales) as total_sales
from product as p 
Inner join date_ship as d 
Using(Number_id)
where  EXTRACT(YEAR FROM Order_Date) = (SELECT max(EXTRACT(YEAR FROM Order_Date)) from date_ship)
Group by 1
order by total_sales desc
Limit 5;
/*Question2. Which days of the week have the highest sales volume? Where Sunday=1, Saturday=7*/
Select  DAYOFWEEK(Order_Date) as days_of_week, 
        sum(Sales)
from product as p 
Inner join date_ship as d 
Using(Number_id)
Group by 1
order by 2 desc;
/*Question3. Which geographical region has the highest average customer spending?*/
Select region, 
       Round((sum(sales)/count(distinct customer_id)),2) as avg_sales_per_customer
from product as p 
Inner join customer as c 
Using(Number_id)
Group by 1
Order by 2 desc;
/*Question4. How do sales volumes of specific products(Staple envelope) change over time?*/
/*First, let's find out which product has been sold for the most number of years.*/
Select Product_name, 
       count(EXTRACT(YEAR FROM Order_Date)) as year_sales
from product as p 
Inner join date_ship as d 
Using(Number_id)
Group by 1
order by 2 desc
limit 1;
/*It turned out to be the <Staple envelope>, so we will investigate its sales changes over time*/
with year_product as (
            Select Product_name,
                   EXTRACT(YEAR FROM Order_Date) AS year_sales,
                   sum(sales) as base_sales_year
            FROM product AS p 
            INNER JOIN date_ship AS d 
            USING (Number_id)
            Where Product_name = 'Staple envelope'
            Group by 1,2
            order by 2
),
     current_next_first_year as (
            SELECT Product_name, 
                    year_sales,
                    base_sales_year,
                    LEAD(base_sales_year, 1) OVER (ORDER BY year_sales) AS next_year_sales,
                    first_value(base_sales_year) OVER ( ORDER BY year_sales) as base_year_2001
            FROM year_product)
Select year_sales, 
       Round(((((next_year_sales-base_sales_year)/base_sales_year)*100)+100),2) as Relative_dynamics_between_years,
       Round(((((next_year_sales-base_year_2001)/base_year_2001)*100)+100),2) as Relative_dynamics_with_a_base_year_2001
from current_next_first_year; 
/*Question5. Rank most sales product evety year*/
with ranked_products as (
       Select Product_name,
              EXTRACT(YEAR FROM Order_Date) as year_sales,
              sum(Sales) as total_sales,
              RANK() OVER(PARTITION BY EXTRACT(YEAR FROM Order_Date) ORDER BY SUM(Sales) DESC) AS rank_product
       From product as p 
       Inner join date_ship as d 
       Using(Number_id)
       group by 1,2
       order by 2,3 desc)
Select Product_name,
       year_sales,
       total_sales
FROM ranked_products
WHERE rank_product = 1;    
/*First we add new column - "purchase"*/
ALTER TABLE product 
ADD COLUMN purchase DECIMAL(10, 2) AFTER Product_name;
/*We add infomation about purchase*/
Update product as p
 Join (Select Number_id,
        ABS(Round((((1 - Discount / 100)*(sales*Quantity)-Profit)/ Quantity),2)) as purchase
from product) as p1 on p.Number_id = p1.Number_id
Set p.purchase = p1.purchase;
/*The company sells a wide range of products. You need to investigate the sales dynamics of a specific product Sub_Category (Phones) within a particular region(South) over the past years(5).*/
with rank_year as (
       Select 
             Sub_Category,
             Profit,
             EXTRACT(year from Order_Date) as Y_ear,
             dense_rank() over(PARTITION by Sub_Category order by EXTRACT(year from Order_Date) desc) as rank_y
       from product as p
       inner join customer as c 
       Using(Number_id)
       inner join date_ship as d 
       Using(Number_id)
       where Sub_Category = 'Phones' 
       and region = 'South'),
year_profit as (  
       Select 
            Y_ear,
            sum(Profit) as total_profit
       FROM rank_year 
       WHERE rank_y < 6
       GROUP BY Y_ear 
       ORDER BY Y_ear),
 next_base_year as (      
       Select 
             Y_ear,
             total_profit,
             LEAD(total_profit, 1) OVER (ORDER BY  Y_ear) AS next_year,
             first_value(total_profit) OVER ( ORDER BY  Y_ear) as base_year
       from year_profit)
select 
      Round(((((next_year-total_profit)/total_profit)*100) + 100),2) as Relative_dynamics_between_years,
      Round(((((total_profit-base_year)/base_year)*100)+100),2) as Relative_dynamics_with_a_base_year
from next_base_year;
/*We will forecast future sales levels.*/
WITH sales_data AS (
    SELECT 
        EXTRACT(year FROM Order_Date) AS Y_ear,
        SUM(Profit) AS total_profit
    FROM product AS p
    INNER JOIN customer AS c 
    USING (Number_id)
    INNER JOIN date_ship AS d 
    USING (Number_id)
    WHERE Sub_Category = 'Phones' 
        AND region = 'South'
    GROUP BY 1
),
exponential_smoothing AS (
    SELECT 
        Y_ear,
        total_profit,
        AVG(total_profit) OVER (ORDER BY Y_ear ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING) AS smoothed_sales
    FROM sales_data
)
SELECT 
    Y_ear + 1 AS Next_Year,
    COALESCE(ROUND(2 * smoothed_sales - total_profit, 2), 0) AS Forecasted_Sales
FROM exponential_smoothing
WHERE Y_ear = (SELECT MAX(Y_ear) FROM exponential_smoothing)
ORDER BY 1;

