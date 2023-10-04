SELECT (avg_trip_distance/avg_duration) as avg_distance_per_duration
, year
, month 
, type 
FROM dbt_nyc_metrics.silver_nyctaxi_avg_metrics