import pandas as pd

df = pd.read_csv("Datasets/fact_ad_revenue.csv")
# Parse year from quarter
import re
def get_year(q):
    m = re.search(r'\b(\d{4})\b', q)
    if m:
        return int(m.group(1))
    return None

df['year'] = df['quarter'].apply(get_year)
df['ad_revenue_clean'] = df['ad_revenue'].apply(lambda x: float(str(x).replace(',', '').strip()))

print("Grouping by year, ad_category, and currency:")
print(df.groupby(['year', 'ad_category', 'currency'])['ad_revenue_clean'].sum())
