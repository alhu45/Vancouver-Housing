# Force Spark to use the S3A magic committer for better stability
import spark

spark.conf.set("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")

# Attempt a native Spark read
try:
    path = "s3a://vancouver-data-bronze-dev/crime/raw/van_crime.csv"
    df_debug = spark.read.format("csv") \
        .option("header", "true") \
        .load(path)
    
    # Trigger an actual 'Action' to see if it hangs
    print(f"Total rows: {df_debug.count()}")
    display(df_debug.limit(5))
except Exception as e:
    print(f"Spark Native Error: {e}")