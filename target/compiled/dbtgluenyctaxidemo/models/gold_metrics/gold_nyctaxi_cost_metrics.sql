SELECT (avg_total_amount/avg_trip_distance) as avg_cost_per_distance
, (avg_total_amount/avg_duration) as avg_cost_per_minute
, year
, month 
, type 
FROM dbt_nyc_metrics.silver_nyctaxi_avg_metrics