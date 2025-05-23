#!/usr/bin/env python3
# validate_data.py - Script to validate data integrity for Weather_ops
# Created: May 23, 2025

import pandas as pd
import os
import sys

def validate_data():
    # Check if data files exist
    data_paths = ['data/raw_weather.csv', 'data/cleaned_weather.csv']
    for path in data_paths:
        if not os.path.exists(path):
            print(f'Error: Data file {path} not found')
            return False

    # Validate cleaned data
    try:
        df = pd.read_csv('data/cleaned_weather.csv')
        # Check for null values in critical columns
        critical_columns = ['tavg', 'tmin', 'tmax', 'prcp', 'wspd']
        for col in critical_columns:
            if col in df.columns and df[col].isnull().sum() > 0:
                print(f'Warning: {df[col].isnull().sum()} null values found in {col}')
        print('Data validation completed successfully')
        return True
    except Exception as e:
        print(f'Error during data validation: {str(e)}')
        return False

if __name__ == "__main__":
    success = validate_data()
    if not success:
        sys.exit(1)
