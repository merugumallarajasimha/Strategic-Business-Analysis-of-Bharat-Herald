import pandas as pd
import re

# Load raw data
df = pd.read_csv("Datasets/fact_ad_revenue.csv")

# Helper function to clean numeric values to floats
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

# Helper function to convert foreign currencies to INR
def normalize_currency_val(revenue, currency):
    curr = str(currency).strip().upper()
    if curr == 'USD':
        return revenue * 80.0
    elif curr == 'EUR':
        return revenue * 85.0
    elif curr in ['INR', 'IN RUPEES']:
        return revenue * 1.0
    else:
        return revenue

# Helper function to normalize quarter format (e.g. 2019-Q1)
def get_year(q):
    if not isinstance(q, str):
        return q
    q = q.strip()
    # Already YYYY-Q#
    m = re.match(r'^(\d{4})-Q[1-4]$', q)
    if m:
        return int(m.group(1))
    # Format: Q#-YYYY
    m = re.match(r'^Q([1-4])-(\d{4})$', q)
    if m:
        return int(m.group(2))
    # Format: #th Qtr YYYY
    m = re.match(r'^(\d)th\s+Qtr\s+(\d{4})$', q)
    if m:
        return int(m.group(2))
    # Let's search for 4-digit number
    m = re.search(r'\b(\d{4})\b', q)
    if m:
        return int(m.group(1))
    return None

df['year'] = df['quarter'].apply(get_year)
df['revenue_val'] = df['ad_revenue'].apply(clean_numeric_float)
df['revenue_inr'] = df.apply(lambda r: normalize_currency_val(r['revenue_val'], r['currency']), axis=1)

print("Total rows:", len(df))
print("Rows with missing years:", df['year'].isna().sum())

# Group by year and ad_category
cat_rev = df.groupby(['year', 'ad_category'])['revenue_inr'].sum().reset_index()
tot_rev = df.groupby('year')['revenue_inr'].sum().reset_index().rename(columns={'revenue_inr': 'total_revenue'})

merged = pd.merge(cat_rev, tot_rev, on='year')
merged['pct'] = (merged['revenue_inr'] / merged['total_revenue']) * 100
print(merged.sort_values(by=['year', 'pct'], ascending=[True, False]))
