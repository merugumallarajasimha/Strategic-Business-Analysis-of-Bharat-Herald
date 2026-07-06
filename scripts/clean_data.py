import os
import re
import pandas as pd

def clean_numeric_int(val):
    if pd.isna(val):
        return 0
    if isinstance(val, (int, float)):
        return int(val)
    val_str = str(val).strip()
    val_str = re.sub(r'[^\d\-]', '', val_str)  # Keep digits and minus
    if val_str == '':
        return 0
    return int(val_str)

def clean_numeric_float(val):
    if pd.isna(val):
        return 0.0
    if isinstance(val, (int, float)):
        return float(val)
    val_str = str(val).strip()
    val_str = re.sub(r'[^\d\.\-]', '', val_str)
    if val_str == '':
        return 0.0
    try:
        return float(val_str)
    except ValueError:
        return 0.0

def normalize_quarter(q):
    if not isinstance(q, str):
        return q
    q = q.strip()
    # Format: YYYY-Q# (e.g., 2023-Q2)
    if re.match(r'^\d{4}-Q[1-4]$', q):
        return q
    # Format: Q#-YYYY (e.g., Q1-2019)
    m = re.match(r'^Q([1-4])-(\d{4})$', q)
    if m:
        return f"{m.group(2)}-Q{m.group(1)}"
    # Format: #th Qtr YYYY (e.g., 4th Qtr 2020)
    m = re.match(r'^(\d)th\s+Qtr\s+(\d{4})$', q)
    if m:
        return f"{m.group(2)}-Q{m.group(1)}"
    return q

def normalize_currency_value(row):
    revenue = row['raw_ad_revenue']
    curr = str(row['currency']).strip().upper()
    if curr == 'USD':
        return revenue * 80.0
    elif curr == 'EUR':
        return revenue * 85.0
    elif curr in ['INR', 'IN RUPEES']:
        return revenue * 1.0
    else:
        return revenue

def main():
    print("Starting data cleaning process...")
    
    # Paths
    datasets_dir = "Datasets"
    cleaned_dir = "Datasets_Cleaned"
    if not os.path.exists(datasets_dir):
        datasets_dir = "../Datasets"
        cleaned_dir = "../Datasets_Cleaned"
        
    os.makedirs(cleaned_dir, exist_ok=True)
    
    # State mapping dictionary
    state_map = {
        'Delhi': 'Delhi',
        'Delhi ': 'Delhi',
        'Uttar-Pradesh': 'Uttar Pradesh',
        'Uttar Pradesh': 'Uttar Pradesh',
        'Uttar pradesh': 'Uttar Pradesh',
        'Madhya_Pradesh': 'Madhya Pradesh',
        'Madhya Pradesh': 'Madhya Pradesh',
        'Bihar': 'Bihar',
        'Rajasthan': 'Rajasthan',
        'Maharashtra': 'Maharashtra',
        'Jharkhand': 'Jharkhand',
        'Gujarat': 'Gujarat'
    }

    # 1. Clean dim_city.xlsx
    print("Cleaning dim_city.xlsx...")
    df_city = pd.read_excel(os.path.join(datasets_dir, "dim_city.xlsx"), sheet_name="in")
    df_city['city'] = df_city['city'].str.strip().str.title()
    df_city['state'] = df_city['state'].str.strip().str.title()
    df_city['state'] = df_city['state'].replace(state_map)
    df_city['tier'] = df_city['tier'].str.strip()
    df_city.to_excel(os.path.join(cleaned_dir, "dim_city.xlsx"), sheet_name="in", index=False)
    
    # 2. Clean dim_ad_category.xlsx
    print("Standardizing dim_ad_category.xlsx...")
    df_cat = pd.read_excel(os.path.join(datasets_dir, "dim_ad_category.xlsx"), sheet_name="in")
    df_cat['standard_ad_category'] = df_cat['standard_ad_category'].str.strip()
    df_cat['category_group'] = df_cat['category_group'].str.strip()
    df_cat['example_brands'] = df_cat['example_brands'].str.strip()
    df_cat.to_excel(os.path.join(cleaned_dir, "dim_ad_category.xlsx"), sheet_name="in", index=False)

    # 3. Clean fact_print_sales.xlsx
    print("Cleaning fact_print_sales.xlsx...")
    df_print = pd.read_excel(os.path.join(datasets_dir, "fact_print_sales.xlsx"), sheet_name="fact_print_sales")
    # Clean copies printed (Copies Sold in Excel)
    df_print['copies_printed_cleaned'] = df_print['Copies Sold'].apply(clean_numeric_int)
    df_print['copies_returned_cleaned'] = df_print['copies_returned'].apply(clean_numeric_int)
    df_print['Language'] = df_print['Language'].str.strip().str.title()
    df_print['State'] = df_print['State'].str.strip().str.title()
    df_print['State'] = df_print['State'].replace(state_map)
    
    # Enforce strict mathematical constraint: net_circulation = copies_printed - copies_returned
    df_print['net_circulation_cleaned'] = df_print['copies_printed_cleaned'] - df_print['copies_returned_cleaned']
    
    # Create final clean print sales DataFrame matching schema
    df_print_clean = pd.DataFrame({
        'edition_id': df_print['edition_ID'],
        'city_id': df_print['City_ID'],
        'language': df_print['Language'],
        'state': df_print['State'],
        'month': pd.to_datetime(df_print['Month']),
        'copies_printed': df_print['copies_printed_cleaned'],
        'copies_returned': df_print['copies_returned_cleaned'],
        'net_circulation': df_print['net_circulation_cleaned']
    })
    
    df_print_clean.to_excel(os.path.join(cleaned_dir, "fact_print_sales.xlsx"), sheet_name="fact_print_sales", index=False)

    # 4. Clean fact_ad_revenue.csv
    print("Cleaning fact_ad_revenue.csv...")
    df_rev = pd.read_csv(os.path.join(datasets_dir, "fact_ad_revenue.csv"))
    df_rev['raw_ad_revenue'] = df_rev['ad_revenue'].apply(clean_numeric_float)
    df_rev['quarter'] = df_rev['quarter'].apply(normalize_quarter)
    df_rev['ad_revenue_in_inr'] = df_rev.apply(normalize_currency_value, axis=1)
    
    # Clean currency column (standardize IN RUPEES and others to INR/USD/EUR in uppercase)
    df_rev['currency_cleaned'] = df_rev['currency'].str.strip().str.upper().replace({'IN RUPEES': 'INR'})
    
    # Map edition_id to city_id
    df_rev['city_id'] = df_rev['edition_id'].apply(lambda x: f"C0{x[4:]}" if len(x) >= 6 else x)
    
    df_rev_clean = pd.DataFrame({
        'edition_id': df_rev['edition_id'],
        'city_id': df_rev['city_id'],
        'ad_category_id': df_rev['ad_category'],
        'quarter': df_rev['quarter'],
        'raw_ad_revenue': df_rev['raw_ad_revenue'],
        'currency': df_rev['currency_cleaned'],
        'ad_revenue_in_inr': df_rev['ad_revenue_in_inr'],
        'comments': df_rev['comments']
    })
    
    df_rev_clean.to_csv(os.path.join(cleaned_dir, "fact_ad_revenue.csv"), index=False)

    # 5. Clean fact_city_readiness.csv
    print("Cleaning fact_city_readiness.csv...")
    df_read = pd.read_csv(os.path.join(datasets_dir, "fact_city_readiness.csv"))
    df_read['quarter_cleaned'] = df_read['quarter'].apply(normalize_quarter)
    df_read['literacy_rate_cleaned'] = df_read['literacy_rate'].apply(clean_numeric_float)
    df_read['smartphone_penetration_cleaned'] = df_read['smartphone_penetration'].apply(clean_numeric_float)
    df_read['internet_penetration_cleaned'] = df_read['internet_penetration'].apply(clean_numeric_float)
    
    df_read_clean = pd.DataFrame({
        'city_id': df_read['city_id'],
        'quarter': df_read['quarter_cleaned'],
        'literacy_rate': df_read['literacy_rate_cleaned'],
        'smartphone_penetration': df_read['smartphone_penetration_cleaned'],
        'internet_penetration': df_read['internet_penetration_cleaned']
    })
    
    df_read_clean.to_csv(os.path.join(cleaned_dir, "fact_city_readiness.csv"), index=False)

    # 6. Clean fact_digital_pilot.csv
    print("Cleaning fact_digital_pilot.csv...")
    df_pilot = pd.read_csv(os.path.join(datasets_dir, "fact_digital_pilot.csv"))
    df_pilot['dev_cost_cleaned'] = df_pilot['dev_cost'].apply(clean_numeric_float)
    df_pilot['marketing_cost_cleaned'] = df_pilot['marketing_cost'].apply(clean_numeric_float)
    df_pilot['users_reached_cleaned'] = df_pilot['users_reached'].apply(clean_numeric_int)
    df_pilot['downloads_or_accesses_cleaned'] = df_pilot['downloads_or_accesses'].apply(clean_numeric_int)
    df_pilot['avg_bounce_rate_cleaned'] = df_pilot['avg_bounce_rate'].apply(clean_numeric_float) / 100.0
    
    df_pilot_clean = pd.DataFrame({
        'platform': df_pilot['platform'].str.strip(),
        'launch_month': df_pilot['launch_month'].str.strip(),
        'ad_category_id': df_pilot['ad_category_id'].str.strip(),
        'dev_cost': df_pilot['dev_cost_cleaned'],
        'marketing_cost': df_pilot['marketing_cost_cleaned'],
        'users_reached': df_pilot['users_reached_cleaned'],
        'downloads_or_accesses': df_pilot['downloads_or_accesses_cleaned'],
        'avg_bounce_rate': df_pilot['avg_bounce_rate_cleaned'],
        'cumulative_feedback_from_customers': df_pilot['cumulative_feedback_from_customers'],
        'city_id': df_pilot['city_id']
    })
    
    df_pilot_clean.to_csv(os.path.join(cleaned_dir, "fact_digital_pilot.csv"), index=False)

    print("Data cleaning completed successfully. Cleaned files saved to:", cleaned_dir)

if __name__ == "__main__":
    main()
