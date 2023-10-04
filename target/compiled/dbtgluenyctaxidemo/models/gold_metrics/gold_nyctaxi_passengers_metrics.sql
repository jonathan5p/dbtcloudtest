SELECT (avg_total_amount/avg_passenger_count) as avg_cost_per_passenger
, (avg_duration/avg_passenger_count) as avg_duration_per_passenger
, (avg_trip_distance/avg_passenger_count) as avg_trip_distance_per_passenger
, year
, month 
, type 
FROM dbt_nyc_metrics.silver_nyctaxi_avg_metrics