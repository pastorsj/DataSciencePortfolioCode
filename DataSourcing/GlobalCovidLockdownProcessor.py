import pandas as pd
import pprint
from datetime import datetime
import glob
import os
import s3


class GlobalCovidLockdownProcessor:

    def __init__(self, file_storage, s3_api):
        self._file_storage = file_storage
        self._lockdown_file_path = f'{self._file_storage.get_raw_base_path()}/lockdown_data/lockdown_data.csv'
        self._start_of_covid = pd.to_datetime('2019-12-01') # Per wikipedia
        self._covid_date_range = pd.date_range(start='2019-12-01', end=datetime.today())
        self._covid_date_range = self._covid_date_range[self._covid_date_range.day == 1]
        self._s3 = s3_api

    def process_global_lockdown_data(self):
        df = pd.read_csv(self._lockdown_file_path)
        df[['StartDate', 'EndDate']] = df[['StartDate', 'EndDate']].apply(pd.to_datetime)
        united_states = df[(df['Country'] == 'United States') & (df['Confirmed'])]
        print(len(united_states))

        for state in united_states.groupby(by='Place'):
            extracted_state = state[0]
            print('Processing lockdown data for state', extracted_state)
            start_date = state[1]['StartDate'].values[0]
            end_date = state[1]['EndDate'].values[0]
            rows = list()
            for month in self._covid_date_range:
                lockdown_exists = start_date <= pd.to_datetime(month) <= end_date
                rows.append({
                    'Date': month.strftime('%Y-%m-%d'),
                    'InLockdown': lockdown_exists,
                    'State': extracted_state
                })

            df = pd.DataFrame(rows)
            print('Storing lockdown data as a dataframe for', extracted_state)
            self._file_storage.store_processed_df_as_file(f'lockdown_data/{extracted_state}.csv', df)

    def store_processed_data(self):
        processed_files = list(glob.iglob(f'{self._file_storage.get_processed_base_path()}/lockdown_data/*.csv'))
        for file in processed_files:
            print('Processing and storing in s3', file)
            filename = os.path.basename(file).strip()
            lockdown_data = pd.read_csv(file, index_col=False)
            print('Attempting to upload processed lockdown data to s3')
            self._s3.upload_df(lockdown_data, f'lockdown_data/{filename}', s3.S3_Location.PROCESSED_DATA)
            print('Successfully uploaded')



if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()
    GlobalCovidLockdownProcessor(FileStorage(), s3.S3_API()).process_global_lockdown_data()
    GlobalCovidLockdownProcessor(FileStorage(), s3.S3_API()).store_processed_data()