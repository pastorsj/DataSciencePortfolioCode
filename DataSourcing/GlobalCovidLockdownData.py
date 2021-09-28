import pandas as pd
import pprint
import os
import s3

class GlobalCovidLockdownData:

    def __init__(self, file_storage, s3_api):
        self._file_storage = file_storage
        self._lockdown_api = 'https://covid19-lockdown-tracker.netlify.app/lockdown_dates.csv'
        self._s3_api = s3_api

    def retrieve_lockdown_data(self):
        lockdown_data = pd.read_csv(self._lockdown_api)
        print(lockdown_data.head())
        print('Saving to file')
        self._file_storage.store_df_as_file('lockdown_data/lockdown_data.csv', lockdown_data)

    def store_raw_data(self):
        file = f'{self._file_storage.get_raw_base_path()}/lockdown_data/lockdown_data.csv'
        print('Processing and storing in s3', file)
        filename = os.path.basename(file).strip()
        lockdown_data = pd.read_csv(file, index_col=False)
        print('Attempting to upload raw lockdown data to s3')
        self._s3_api.upload_df(lockdown_data, f'lockdown_data/{filename}', s3.S3_Location.RAW_DATA)
        print('Successfully uploaded')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()
    GlobalCovidLockdownData(FileStorage(), s3.S3_API()).retrieve_lockdown_data()
    GlobalCovidLockdownData(FileStorage(), s3.S3_API()).store_raw_data()
