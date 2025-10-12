import pandas as pd
from model import engineer_features, hazard_score

df = pd.read_csv("balanced_training_data.csv")
df = engineer_features(df)
df["event"] = df.apply(hazard_score, axis=1)
print(df["event"].value_counts())