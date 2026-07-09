import pandas as pd

df = pd.read_csv("Datasets/fact_ad_revenue.csv")
print("Raw sums by ad_category (without currency translation):")
print(df.groupby('ad_category')['ad_revenue'].sum())

print("\nRaw sums by currency:")
print(df.groupby('currency')['ad_revenue'].sum())
