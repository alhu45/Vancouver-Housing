def fast_spark_read(bucket, key):
    import boto3
    import pandas as pd
    import io
    s3 = boto3.client('s3')

    # Use the fast boto3 connection
    obj = s3.get_object(Bucket=bucket, Key=key)

    # Convert to Spark via Pandas (for smaller files < 500MB)
    return spark.createDataFrame(pd.read_csv(io.BytesIO(obj['Body'].read())))

# Use it for your crime data
df_crime = fast_spark_read('vancouver-data-bronze-dev', 'crime/raw/van_crime.csv')

display(df_crime)