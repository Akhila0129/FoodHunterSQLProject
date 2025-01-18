select * from orders;
select order_id,delivered_date from orders limit 10000;

#1. display the records from 100001 to 20000
select order_id,delivered_date from orders limit 20000 offset 10000; 

#2. how many distinct orders in the ds
select count(distinct(order_id)) from orders;

#3. driver count
select count(driver_id) from orders;
select count(distinct(driver_id)) from orders;          #total no.of drivers

#4. find the starting and ending dates of ds
select min(order_date) from orders;
select max(order_date) from orders;

#5. now filter the data wrt months to find trends for decreasing revenue
select count(order_id) from orders
where order_date>= '2022-06-01' and order_date<='2022-06-30';

select count(order_id) from orders
where order_date>= '2022-07-01' and order_date<='2022-07-31';

select count(order_id) from orders
where order_date>= '2022-08-01' and order_date<='2022-08-31';

select count(order_id) from orders
where order_date between '2022-09-01' and '2022-09-30';

#Simply extract orders in one single function
select order_date,count(order_id) as OrdersCount from orders group by order_date;

#6. Extract no.of orders received per each month in a single query
select month(order_date) as OrderMonth,count(order_id) as OrderCount 
from orders 
group by OrderMonth
order by OrderCount desc;        #Observed a downward trend on orders received

#7. Extract total revenue per month
select month(order_date) as OrderMonth,sum(final_price) as TotalRevenue
from orders
group by OrderMonth
order by TotalRevenue desc;    #Observed a downward trend on revenue

#Now lets analyze the reasons(root cause) for this downward trend.
# 8. LETS START WITH TOTAL DISCOUNT TRENDS OVER MONTHS
select month(order_date) as OrderMonth,sum(discount) as TotalDiscount, 
round(sum(final_price),0) as TotalRevenue
from orders
group by OrderMonth
order by OrderMonth;   #We observed a downward trend in discount. This cant be exactly true. For this need to analyze the discount/revenue ratio.

select month(order_date) as OrderMonth, sum(discount) as TotalDiscount, sum(final_price) as TotalRevenue, 
sum(discount)/sum(final_price) as Discount_Revenue_Ratio,
count(order_id) as OrderCount
from orders
group by OrderMonth
order by OrderMonth;     #we observed that ratio is consistent over a period.This might not be affecting the revenue

#9. LETS LOOK AT THE TRENDS wrt DAY OF A WEEK TO SEE THE WEEKDAY OR WEEKEND EFFECT
select dayofweek(order_date) as Wday, sum(final_price) as TotalRevenue, count(order_id) as OrderCount, sum(discount) as TotalDiscount
from orders
group by Wday
order by Wday;    #Sat and sunday have lowest sales comp to weekdays except tuesday

#Lets dive to segregate as weekday or weekend. To do this need to add new col
select sum(final_price) as TotalRevenue, count(order_id) as OrderCount, sum(discount) as TotalDisc,
case
when dayofweek(order_date)=1 then 'Weekend'
when dayofweek(order_date)=7 then 'Weekend'
else 'Weekday'
end as Wday
from orders
group by Wday;                #weekday/5=6250,weekend/2=5900. Evident that weekdyas have high revenue compared to weekednds

#10. NOW LETS SEE THE TRENDS OVER MONTHS WRT WEEKDAYS AND WEEKENDS WITH COMPARISION OF PREV MONTH
#step1: see the trends of revenue over months for weekdays and weekends
select
case
when dayofweek(order_date)=1 then 'Weekend'
when dayofweek(order_date)=7 then 'Weekend'
else 'Weekday'
end as Wday,
month(order_date) as OrderMonth, round(sum(final_price),0) as TotalRevenue
from orders
group by OrderMonth, Wday;

#Step2: Goal is to aDD new col with previous month revenue records using windows functions
select *,
lag(TotalRevenue) over (partition by Wday) as PrevRev
from
(
select
case
when dayofweek(order_date)=1 then 'Weekend'
when dayofweek(order_date)=7 then 'Weekend'
else 'Weekday'
end as Wday,
month(order_date) as OrderMonth, round(sum(final_price),0) as TotalRevenue
from orders
group by OrderMonth, Wday
order by Wday
) t1;

#step 3: Finding the % change in revenue for each record
select * from
(select *,
lag(TotalRevenue) over (partition by Wday) as PrevRev
from
(
select
case
when dayofweek(order_date)=1 then 'Weekend'
when dayofweek(order_date)=7 then 'Weekend'
else 'Weekday'
end as Wday,
month(order_date) as OrderMonth, round(sum(final_price),0) as TotalRevenue
from orders
group by OrderMonth, Wday
order by Wday) 
t1) 
t2;

#step4: adding % change column
select *,
round(((TotalRevenue-PrevRev)/PrevRev)*100) as Percentage_Change
from
(
select *,
lag(TotalRevenue) over (partition by Wday) as PrevRev
from
(
select
case
when dayofweek(order_date)=1 then 'Weekend'
when dayofweek(order_date)=7 then 'Weekend'
else 'Weekday'
end as Wday,
month(order_date) as OrderMonth, round(sum(final_price),0) as TotalRevenue
from orders
group by OrderMonth, Wday
order by Wday) 
t1) 
t2;      # found that weekend sales have to be increased.alter

#11. LETS SEE TRENDS IN DELIVERY TIME OVER MONTHS AND CHECK IF IT IMPACTS ON REVENUE
select month(order_date) as OrderMonth,
avg(timestampdiff(minute,order_time,delivered_time)) as avg_delivery_time
from orders
group by OrderMonth;                #Delivery time is increasing by month. It effects the revenue.

#12. LETS SEE HOW DELIVERY PARTNERS PERFORMED BASED ON AVG DELIVERY TIME
#step:1-> obtain the avg time value for each driver
select month(order_date) as OrderMonth, driver_id,avg(minute(timediff(delivered_time,order_time))) as AverageTime
from orders
group by OrderMonth, driver_id;

#step:2-> based on o/p of prev query, now partition based on Order_Month and order them by avgtime and give them a rank
select OrderMonth, driver_id,AverageTime, rank() over (partition by OrderMonth order by AverageTime) as driver_rank
from
(
select month(order_date) as OrderMonth, driver_id,avg(minute(timediff(delivered_time,order_time))) as AverageTime
from orders
group by OrderMonth, driver_id
) as q1;

#step3->Get the five best performing drivers of each month
select * from
(
select OrderMonth, driver_id,AverageTime, rank() over (partition by OrderMonth order by AverageTime) as driver_rank
from
(
select month(order_date) as OrderMonth, driver_id,avg(minute(timediff(delivered_time,order_time))) as AverageTime
from orders
group by OrderMonth, driver_id
) as q1
)q2
where driver_rank between 1 and 5;

#**********************************************************************************************
#TASk: The task at hand is
#1. Break down the timings into 4 sections. It can be based on the meal of the day, 
#     i.e. (Breakfast, Lunch, Brunch, and Dinner) or divide time into 4 buckets (6 AM-12 PM, 12 PM-6 PM, 6 PM-12 AM, and 12 AM-6 AM). 
#2. Identify which time bucket or segment customers prefer across four months.
#3. Find the percentage changes in the revenue across four time segments over four months.

#1.
select month(order_date) as OrderMonth,
case
when hour(order_time) between 6 and 11 then '6am-12pm'
when hour(order_time) between 12 and 17 then '12pm-6pm'
when hour(order_time) between 18 and 23 then '6pm-12am'
else '12am-6am'
end as time_segment,
round(sum(final_price),0) as TotalRevenue
from orders
group by OrderMonth,time_segment
order by OrderMonth,TotalRevenue desc;

#2. Manually we can say which segment is preferred

#3. 
select *,
((TotalRevenue-(lag(TotalRevenue) over (partition by OrderMonth)))/(lag(TotalRevenue) over (partition by OrderMonth)))*100 as 'percet_change'
from
(
select month(order_date) as OrderMonth,
case
when hour(order_time) between 6 and 11 then '6am-12pm'
when hour(order_time) between 12 and 17 then '12pm-6pm'
when hour(order_time) between 18 and 23 then '6pm-12am'
else '12am-6am'
end as time_segment,
round(sum(final_price),0) as TotalRevenue
from orders
group by OrderMonth,time_segment
order by OrderMonth,TotalRevenue desc
) q1;

# Till now we observered a downward trend in revenue,orders count and avg delivery is increasing over months.
#Now lets see the food preferences and its trends using food_items table
select * from food_items;
select * from orders_items;

select * from orders_items oi
left join food_items fi
on oi.item_id=fi.item_id;

select count(*) from orders_items oi
left join food_items fi
on oi.item_id=fi.item_id;     #64727

select count(*) from orders_items oi
inner join food_items fi
on oi.item_id=fi.item_id;     #64727
#So the abouve two codes conclude that we have description present in food item table also exists for every item in orders table

#FIND THE NO.OF ORDERS FOR EACH FOOD TYPE( food type, quantity)
#See the o/p
select fi.food_type, sum(oi.quantity) as ItemQuantity 
from orders_items oi
left join food_items fi
on oi.item_id=fi.item_id
group by fi.food_type
order by ItemQuantity desc;

#lets standardise the food type: vegetarian to veg, non vegetarian as non-veg-> LIKE-> used to match a set of characters
select item_id,
case
when food_type like 'veg%' then 'veg'
else 'non-veg'
end as food_type_new
from food_items;

#Now lets combine both
select t2.food_type_new, sum(t1.quantity) as itemquantity
from orders_items as t1
left join 
(
select item_id,
case
when food_type like 'veg%' then 'veg'
else 'non-veg'
end as food_type_new
from food_items
) t2
on t1.item_id=t2.item_id
group by t2.food_type_new;   #Clearly non-veg have an upper hand compared to veg

#FIND THE NO.OF ITEMS ORDERED FROM EACH RESTAURANT
# we need food_items,orders_items,restaurants table and join them
select r.restaurant_name, r.restaurant_id, r.cuisine, sum(quantity) as quantity
from restaurants r
left join food_items as fi on r.restaurant_id=fi.restaurant_id
left join orders_items as oi on fi.item_id=oi.item_id
group by r.restaurant_id
order by quantity;

#now retrieve the data of restaurants with zero orders
select r.restaurant_name, r.restaurant_id, r.cuisine, sum(quantity) as quantity
from restaurants r
left join food_items as fi on r.restaurant_id=fi.restaurant_id
left join orders_items as oi on fi.item_id=oi.item_id
group by r.restaurant_id
order by quantity;
# where quantity=0; # error bcz we can't use where clausenpost aggregation i.e., groupby. In such cases we need to use 'having' clause

select r.restaurant_name, r.restaurant_id, r.cuisine, sum(quantity) as quantity
from restaurants r
left join food_items as fi on r.restaurant_id=fi.restaurant_id
left join orders_items as oi on fi.item_id=oi.item_id
group by r.restaurant_id
having quantity is null
order by quantity;  # groupby->having->orderby 
# from this result I can say that Italian restaurants have most zero orders due to various reasons

