import pandas as pd

df = pd.read_csv("Datasets/fact_ad_revenue.csv")
print("Unique comments:")
print(df['comments'].unique())

print("\nSample rows with comments:")
print(df[df['comments'].notna()][['ad_category', 'quarter', 'ad_revenue', 'currency', 'comments']].head(20))
