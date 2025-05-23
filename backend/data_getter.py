import os
import pandas as pd
from datetime import datetime
from meteostat import Daily, Point

location = Point(12.9716, 77.5946)  # Bangalore
start = datetime(2014, 1, 1)
end = datetime(2023, 12, 31)

data = Daily(location, start, end)
df = data.fetch()
df.reset_index(inplace=True)

df['time'] = pd.to_datetime(df['time'])

existing_path = "data/raw_weather.csv"

if os.path.exists(existing_path):
    existing_data = pd.read_csv(existing_path)
    
    
    existing_data['time'] = pd.to_datetime(existing_data['time'])
    

    new_data = df[~df['time'].isin(existing_data['time'])]
    
    if not new_data.empty:
        combined = pd.concat([existing_data, new_data], ignore_index=True)
        combined = combined.drop_duplicates(subset='time').sort_values('time')
        combined.to_csv(existing_path, index=False)
        print("✅ Appended new data to data/raw_weather.csv")
    else:
        print("🔄 No new data to append.")
else:
    os.makedirs("data", exist_ok=True)
    df.to_csv(existing_path, index=False)
    print("✅ Raw data saved to data/raw_weather.csv")
