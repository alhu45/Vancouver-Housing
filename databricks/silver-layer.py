from pyspark.sql.functions import col, concat, lit, lpad, to_timestamp
from pyspark.sql.functions import when

# Silver Cleaning for Crime Data
df_crime = spark.read.table("workspace_ingestion_data.default.`raw-crime`")

df_crime = df_crime.drop("_rescued_data")
df_crime = df_crime.dropna()

# Changing the month column to a month name
df_crime = df_crime.withColumn("MONTH_NAME",
    when(col("MONTH") == 1, "January")
    .when(col("MONTH") == 2, "February")
    .when(col("MONTH") == 3, "March")
    .when(col("MONTH") == 4, "April") 
    .when(col("MONTH") == 5, "May")
    .when(col("MONTH") == 6, "June")
    .when(col("MONTH") == 7, "July")
    .when(col("MONTH") == 8, "August")
    .when(col("MONTH") == 9, "September")
    .when(col("MONTH") == 10, "October")
    .when(col("MONTH") == 11, "November")
    .when(col("MONTH") == 12, "December")                                              
)

df_crime = df_crime.withColumn("NEIGHBOURHOOD",
    when(col("NEIGHBOURHOOD") == "Stanley Park", "West End")
    .when(col("NEIGHBOURHOOD") == "Central Business District", "Downtown")
    .when(col("NEIGHBOURHOOD") == "Musqueam", "Dunbar-Southlands")
    .when(col("NEIGHBOURHOOD") == "Arbutus Ridge", "Arbutus-Ridge")
    .otherwise(col("NEIGHBOURHOOD"))
)

# Combining date with month
df_crime = df_crime.withColumn("DATE",
    concat(col("MONTH_NAME"), lit(" "), col("DAY").cast("string"))
)

# Drop Columns
df_crime = df_crime.drop("MONTH_NAME", "MONTH", "DAY", "HOUR", "MINUTE")

df_crime = df_crime.withColumnRenamed("HUNDRED_BLOCK", "BLOCK") \
                   .withColumnRenamed("TYPE", "CRIME_TYPE")

# display(df_crime.limit(10))
# display(df_crime.select("NEIGHBOURHOOD").distinct())

df_crime.write.format("delta") \
    .mode("overwrite") \
    .saveAsTable("workspace.silver.crime_clean")
