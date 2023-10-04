
  
    create table dbt_nyc_metrics.silver_nyctaxi_avg_metrics
  using PARQUET
	
	
	
	LOCATION 's3://aws-dbt-glue-datalake-847258583865-us-east-1//dbt_nyc_metrics/silver_nyctaxi_avg_metrics/'
	
	as
	WITH source_avg as ( 
    SELECT avg((CAST(dropoff_datetime as LONG) - CAST(pickup_datetime as LONG))/60) as avg_duration 
    , avg(passenger_count) as avg_passenger_count 
    , avg(trip_distance) as avg_trip_distance 
    , avg(total_amount) as avg_total_amount
    , year
    , month 
    , type
    FROM nyctaxi.records 
    WHERE year = "2016"
    AND dropoff_datetime is not null 
    GROUP BY 5, 6, 7
) 
SELECT *
FROM source_avg
  