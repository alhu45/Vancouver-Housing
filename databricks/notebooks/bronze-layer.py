def fast_spark_read(bucket, key):
    import boto3
    import pandas as pd
    import io

    s3 = boto3.client('s3')
    obj = s3.get_object(Bucket=bucket, Key=key)
    buf = io.BytesIO(obj["Body"].read())

    # 1. Fixed the logic to handle different types correctly
    if key.endswith(".csv"):
        pdf = pd.read_csv(buf)
    elif key.endswith((".xlsx", ".xls")):
        pdf = pd.read_excel(buf, engine="openpyxl")
    elif key.endswith(".txt"): # Added missing colon
        # Most .txt files in transit data are Tab or Comma separated
        # 'sep=None' with 'engine=python' tells pandas to guess the separator
        pdf = pd.read_csv(buf, sep=None, engine='python')
    else:
        raise ValueError(f"Unsupported file type: {key}")
    
    # 2. IMPORTANT: Convert NaN to None so Spark can read it
    pdf = pdf.where(pd.notnull(pdf), None)
    
    return spark.createDataFrame(pdf)  

# Storing Bronze Crime
df_crime = fast_spark_read('vancouver-data-bronze-dev', 'crime/raw/van_crime.csv')
df_crime.write.mode("overwrite").format("delta").saveAsTable("bronze_crime") # Wrties into a Spark Table

# Storing Bronze Housing
df_housing = fast_spark_read('vancouver-data-bronze-dev', 'housing/raw/van_housing.xlsx')
df_housing.write.mode("overwrite").format("delta").saveAsTable("bronze_housing")

# Storing Bronze Transit Text Files
df_transit_cal = fast_spark_read('vancouver-data-bronze-dev', 'transit/raw/calendar.txt')
df_transit_route = fast_spark_read('vancouver-data-bronze-dev', 'transit/raw/routes.txt')
df_transit_stoptime = fast_spark_read('vancouver-data-bronze-dev', 'transit/raw/stop_times.txt')
df_transit_stops = fast_spark_read('vancouver-data-bronze-dev', 'transit/raw/stops.txt')
df_transit_trips = fast_spark_read('vancouver-data-bronze-dev', 'transit/raw/trips.txt')

df_transit_cal.write.mode("overwrite").format("delta").saveAsTable("bronze_transit_calendar")
df_transit_route.write.mode("overwrite").format("delta").saveAsTable("bronze_transit_route")
df_transit_stoptime.write.mode("overwrite").format("delta").saveAsTable("bronze_transit_stop_times")
df_transit_stops.write.mode("overwrite").format("delta").saveAsTable("bronze_transit_stops")
df_transit_trips.write.mode("overwrite").format("delta").saveAsTable("bronze_transit_trips")
