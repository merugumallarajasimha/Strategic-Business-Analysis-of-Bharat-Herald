import psycopg2
import pandas as pd

conn = psycopg2.connect(host="localhost", port=5432, database="bharat_herald", user="postgres", password="postgresql")
df = pd.read_sql_query("SELECT * FROM cleaned.dim_ad_category", conn)
print(df)
conn.close()
