-- Reference DDL for yellow_trips in Redshift Serverless (tlc database).
-- The load_redshift Glue job runs CREATE TABLE IF NOT EXISTS automatically,
-- so this file is for documentation and manual inspection only.

CREATE TABLE IF NOT EXISTS yellow_trips (
    vendor_id           INTEGER,
    pickup_datetime     TIMESTAMP,
    dropoff_datetime    TIMESTAMP,
    passenger_count     INTEGER,
    trip_distance       DOUBLE PRECISION,
    pickup_location_id  INTEGER,
    dropoff_location_id INTEGER,
    payment_type        INTEGER,
    fare_amount         DOUBLE PRECISION,
    tip_amount          DOUBLE PRECISION,
    total_amount        DOUBLE PRECISION
)
DISTSTYLE AUTO
SORTKEY AUTO;

-- Verification queries
SELECT COUNT(*), DATE_TRUNC('month', pickup_datetime) AS month
FROM yellow_trips
GROUP BY 2
ORDER BY 2 DESC;

SELECT AVG(trip_distance)  AS avg_distance,
       AVG(fare_amount)    AS avg_fare,
       AVG(tip_amount)     AS avg_tip,
       COUNT(*)            AS trip_count
FROM yellow_trips;
