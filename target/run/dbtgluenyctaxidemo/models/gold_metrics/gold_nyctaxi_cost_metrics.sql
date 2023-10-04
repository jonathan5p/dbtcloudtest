
  
    create table dbt_nyc_metrics.gold_nyctaxi_cost_metrics
  using PARQUET
	
	
	
	LOCATION 's3://aws-dbt-glue-datalake-847258583865-us-east-1//dbt_nyc_metrics/gold_nyctaxi_cost_metrics/'
	
	as
	SELECT (avg_total_amount/avg_trip_distance) as avg_cost_per_distance
, (avg_total_amount/avg_duration) as avg_cost_per_minute
, year
, month 
, type 
FROM dbt_nyc_metrics.silver_nyctaxi_avg_metrics
  