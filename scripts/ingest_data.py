import os
import sys
import pandas as pd
import psycopg2
from sqlalchemy import create_engine

# Add current directory to path to ensure clean_data can be imported
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import clean_data

# Database connection details
DB_HOST = "localhost"
DB_PORT = 5432
DB_NAME = "bharat_herald"
DB_USER = "postgres"
DB_PASS = "postgresql"

def run_ddl_schema():
    print("Executing schema.sql DDL...")
    schema_path = "sql/schema.sql"
    if not os.path.exists(schema_path):
        schema_path = "../sql/schema.sql"
        
    conn = psycopg2.connect(host=DB_HOST, port=DB_PORT, database=DB_NAME, user=DB_USER, password=DB_PASS)
    conn.autocommit = True
    cur = conn.cursor()
    with open(schema_path, "r", encoding="utf-8") as f:
        ddl = f.read()
    cur.execute(ddl)
    cur.close()
    conn.close()
    print("Schema initialized successfully.")

def main():
    # 1. Run the data cleaning pipeline first
    clean_data.main()

    # 2. Initialize schema
    run_ddl_schema()

    # Create SQLAlchemy engine for pandas to_sql
    engine = create_engine(f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}")

    # Set up datasets path depending on execution directory
    cleaned_dir = "Datasets_Cleaned"
    if not os.path.exists(cleaned_dir):
        cleaned_dir = "../Datasets_Cleaned"

    # 3. Ingest dim_city
    print("Ingesting dim_city from cleaned data...")
    df_city = pd.read_excel(os.path.join(cleaned_dir, "dim_city.xlsx"), sheet_name="in")
    df_city.to_sql("dim_city", engine, if_exists="append", index=False)
    print(f"Loaded {len(df_city)} rows into dim_city.")

    # 4. Ingest dim_ad_category
    print("Ingesting dim_ad_category from cleaned data...")
    df_cat = pd.read_excel(os.path.join(cleaned_dir, "dim_ad_category.xlsx"), sheet_name="in")
    df_cat.to_sql("dim_ad_category", engine, if_exists="append", index=False)
    print(f"Loaded {len(df_cat)} rows into dim_ad_category.")

    # 5. Ingest fact_ad_revenue
    print("Ingesting fact_ad_revenue from cleaned data...")
    df_rev = pd.read_csv(os.path.join(cleaned_dir, "fact_ad_revenue.csv"))
    df_rev.to_sql("fact_ad_revenue", engine, if_exists="append", index=False)
    print(f"Loaded {len(df_rev)} rows into fact_ad_revenue.")

    # 6. Ingest fact_city_readiness
    print("Ingesting fact_city_readiness from cleaned data...")
    df_read = pd.read_csv(os.path.join(cleaned_dir, "fact_city_readiness.csv"))
    df_read.to_sql("fact_city_readiness", engine, if_exists="append", index=False)
    print(f"Loaded {len(df_read)} rows into fact_city_readiness.")

    # 7. Ingest fact_digital_pilot
    print("Ingesting fact_digital_pilot from cleaned data...")
    df_pilot = pd.read_csv(os.path.join(cleaned_dir, "fact_digital_pilot.csv"))
    df_pilot.to_sql("fact_digital_pilot", engine, if_exists="append", index=False)
    print(f"Loaded {len(df_pilot)} rows into fact_digital_pilot.")

    # 8. Ingest fact_print_sales
    print("Ingesting fact_print_sales from cleaned data...")
    df_print = pd.read_excel(os.path.join(cleaned_dir, "fact_print_sales.xlsx"), sheet_name="fact_print_sales")
    df_print['month'] = pd.to_datetime(df_print['month'])
    df_print.to_sql("fact_print_sales", engine, if_exists="append", index=False)
    print(f"Loaded {len(df_print)} rows into fact_print_sales.")

    print("\nData Ingestion Completed Successfully!")

if __name__ == "__main__":
    main()
