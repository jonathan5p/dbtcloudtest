
  
    create table dbt_nyc_metrics.gold_nyctaxi_distance_metrics
  using PARQUET
	
	
	
	LOCATION 's3://aws-dbt-glue-datalake-847258583865-us-east-1//dbt_nyc_metrics/gold_nyctaxi_distance_metrics/'
	
	as
	SELECT (avg_trip_distance/avg_duration) as avg_distance_per_duration
, year
, month 
, type 
FROM dbt_nyc_metrics.silver_nyctaxi_avg_metrics
  