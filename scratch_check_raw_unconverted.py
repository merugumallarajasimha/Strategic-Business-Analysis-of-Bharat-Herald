import pandas as pd
import re

df = pd.read_csv("Datasets/fact_ad_revenue.csv")

def get_year(q):
    m = re.search(r'\b(\d{4})\b', q)
    if m:
        return int(m.group(1))
    return None

df['year'] = df['quarter'].apply(get_year)
df['revenue_clean'] = df['ad_revenue'].apply(lambda x: float(str(x).replace(',', '').strip()))

cat_rev = df.groupby(['year', 'ad_category'])['revenue_clean'].sum().reset_index()
tot_rev = df.groupby('year')['revenue_clean'].sum().reset_index().rename(columns={'revenue_clean': 'total_revenue'})

merged = pd.merge(cat_rev, tot_rev, on='year')
merged['pct'] = (merged['revenue_clean'] / merged['total_revenue']) * 100
print(merged.sort_values(by=['year', 'pct'], ascending=[True, False]))
