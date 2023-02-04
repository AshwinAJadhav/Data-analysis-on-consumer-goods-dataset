	-- ad-hocs --
    
	/* 1. Provide the list of markets in which customer "Atliq Exclusive" operates its 	business in the APAC region.*/
    
		SELECT DISTINCT  market  FROM dim_customer
		WHERE customer = 'Atliq Exclusive' AND  region =  'APAC';
	
	/*2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields,
	 unique_products_2020 , unique_products_2021 ,  percentage_chg*/
     
	WITH  
		a AS (	SELECT ( count(DISTINCT product_code)) AS unique_products_2020
					FROM  fact_sales_monthly 	WHERE  fiscal_year = 2020  ) ,
				b AS (	SELECT ( count( DISTINCT product_code)) AS unique_products_2021
					FROM fact_sales_monthly  	WHERE  fiscal_year = 2021 )
                
	SELECT  a.unique_products_2020 ,  b.unique_products_2021  , 
			(( unique_products_2021 - unique_products_2020 ) /unique_products_2020 ) *100	AS  percentage_chg
	FROM a JOIN b ;

	/* 3. Provide a report with all the unique product counts for each segment and sort them in descending 
	order of product counts. The final output contains 2 fields, segment product_count */
	    
	SELECT segment , count(DISTINCT product_code) AS product_count
	FROM dim_product
	GROUP BY segment
	ORDER BY product_count DESC ;

	/* 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output
	contains these fields, segment product_count_2020 product_count_2021 difference */

	WITH 
		pr_count_2021 AS ( SELECT  segment ,  count( DISTINCT p.product_code ) AS product_count_2021
						FROM   dim_product p
						JOIN fact_sales_monthly s ON  p.product_code = s.product_code 
						WHERE fiscal_year = 2021
						GROUP BY  segment ),
		pr_count_2020 AS ( 	SELECT  segment ,  count( DISTINCT p.product_code ) AS product_count_2020
						FROM   dim_product p
						LEFT JOIN fact_sales_monthly s ON p.product_code = s.product_code 
						WHERE fiscal_year = 2020
						GROUP BY  segment  )
	SELECT pr_count_2020.segment ,product_count_2020 ,product_count_2021 ,
		(pr_count_2021.product_count_2021 -pr_count_2020.product_count_2020 ) AS difference
	FROM pr_count_2021 
    CROSS JOIN pr_count_2020 ON pr_count_2020.segment = pr_count_2021.  segment     
	;

	/*5. Get the products that have the highest and lowest manufacturing costs. The final output should 
	contain these fields, product_code ,product, manufacturing_cost*/ 

	SELECT  m.product_code , product , manufacturing_cost
			FROM dim_product p 
			JOIN fact_manufacturing_cost m	ON   m.product_code = p.product_code	
			WHERE manufacturing_cost = (
						SELECT max(manufacturing_cost) FROM fact_manufacturing_cost)
	UNION 
	SELECT  m.product_code , product , manufacturing_cost
			FROM dim_product p
			JOIN fact_manufacturing_cost m ON p.product_code = m.product_code 
			WHERE manufacturing_cost = (
						SELECT min(manufacturing_cost) FROM fact_manufacturing_cost);

	/*6. Generate a report which contains the top 5 customers who received an average high
	 pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
	 The final output contains these fields, 
	customer_code ,customer, average_discount_percentage*/

	SELECT  c.customer_code , customer ,pre_invoice_discount_pct
		FROM fact_pre_invoice_deductions  i
		JOIN  dim_customer c ON i.customer_code  = c.customer_code
	WHERE   fiscal_year = 2021 AND market = 'India' AND 
			pre_invoice_discount_pct > 
					(SELECT AVG(pre_invoice_discount_pct) FROM fact_pre_invoice_deductions)
	ORDER BY pre_invoice_discount_pct DESC 
	limit 5;

	/*7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. 
	This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
	The final report contains these columns: Month Year Gross sales Amount*/

	SELECT  MONTH(date) as month  , YEAR (date) AS year , SUM(gross_price * sold_quantity ) AS Gross_sales_amount 
		FROM fact_gross_price g  
			JOIN fact_sales_monthly s ON g. product_code = s.product_code
			JOIN dim_customer c ON c. customer_code = s.customer_code 
		WHERE customer = 'Atliq Exclusive'
		GROUP BY  MONTH(date) , YEAR (date) 
		ORDER BY  YEAR (date) 
	 ;

	/* 8. In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these
	 fields sorted by the total_sold_quantity, Quarter total_sold_quantity */
	 SELECT CASE 
				WHEN date BETWEEN '2019-09-01' AND '2019-11-01' THEN 1 
				WHEN date BETWEEN  '2019-12-01' AND '2020-02-01' THEN 2
				WHEN date BETWEEN '2020-03-01' AND '2020-05-01' THEN 3
				WHEN date BETWEEN '2020-06-01' AND '2020-08-01' THEN 4
			END AS QUARTER , SUM(sold_quantity) AS total_sold_quantity 
		FROM fact_sales_monthly
			WHERE fiscal_year = 2020
			GROUP BY QUARTER
			ORDER BY  total_sold_quantity DESC
		;
	/*9. Which channel helped to bring more gross sales in the fiscal year 2021 and the 
	percentage of contribution? The final output contains these fields, channel gross_sales_mln 
	percentage*/

	WITH 
		CHANNEL AS ( SELECT CHANNEL , SUM(round((sold_quantity * gross_price)/1000,2)) AS gross_sales_mln  
			 FROM dim_customer C  
				INNER JOIN fact_sales_monthly S ON C.customer_code = S.customer_code 
				INNER JOIN fact_gross_price G   ON S.product_code = G.product_code
			WHERE S.fiscal_year = 2021
			GROUP BY CHANNEL ) 
	SELECT CHANNEL , gross_sales_mln ,ROUND((S. gross_sales_mln / TOTAL_SALES.TOTAL )*100,2) AS Percentage  
		FROM CHANNEL AS S
		CROSS JOIN (SELECT SUM(gross_sales_mln) AS TOTAL FROM CHANNEL ) TOTAL_SALES
		ORDER BY  gross_sales_mln DESC
	;


	/*10. Get the Top 3 products in each division that have a high total_sold_quantity in the 
	 2021? The final output contains these fields, 
	 division , product_code ,product , total_sold_quantity , rank_order*/
	WITH 
		sales AS ( SELECT division,  M.product_code,product, SUM (sold_quantity) AS total_sold_quantity
				FROM fact_sales_monthly AS M
				LEFT JOIN  dim_product AS P
				ON M.product_code = P.product_code
				WHERE fiscal_year = 2021
				GROUP BY M.product_code, division,product),
		rank_ov AS(	SELECT product_code, total_sold_quantity,
					DENSE_RANK () OVER(PARTITION BY division ORDER BY total_sold_quantity DESC) AS Rank_order
				FROM sales AS S)
	SELECT division, S.product_code,  product ,  S.total_sold_quantity, Rank_order
		FROM sales AS S
		INNER JOIN rank_ov AS R	ON R.product_code = S.product_code
		WHERE Rank_order BETWEEN 1 AND 3
	;
