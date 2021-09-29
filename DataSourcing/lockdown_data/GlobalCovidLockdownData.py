import pandas as pd
import os
import S3Api

# Constants
STORE_DATA = False

class GlobalCovidLockdownData:
    """Retrieves lockdown data from a lockdown tracking api"""

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the GlobalCovidLockdownData class

        Parameters
        ----------
        :param file_storage: FileStorage, Required
            The file storage class used to store raw/processed data
        :param s3_api: S3_API, Required
            The S3 api wrapper class used to store data in AWS S#

        ----------
        """
        self._file_storage = file_storage
        self._lockdown_api = 'https://covid19-lockdown-tracker.netlify.app/lockdown_dates.csv'
        self._s3_api = s3_api

    def retrieve_lockdown_data(self):
        """Retrieves the raw lockdown data from the api and stores it for future use"""
        lockdown_data = pd.read_csv(self._lockdown_api)
        print(lockdown_data.head())
        print('Saving to file')
        lockdown_data[['StartDate', 'EndDate']] = lockdown_data[['Start date', 'End date']]
        lockdown_data = lockdown_data.drop(['Start date', 'End date'], axis=1)
        self._file_storage.store_df_as_file('lockdown_data/lockdown_data.csv', lockdown_data)

    def store_raw_data(self):
        """Stores the raw data in S3"""
        file = f'{self._file_storage.get_raw_base_path()}/lockdown_data/lockdown_data.csv'
        print('Processing and storing in s3', file)
        filename = os.path.basename(file).strip()
        lockdown_data = pd.read_csv(file, index_col=False)
        print('Attempting to upload raw lockdown data to s3')
        self._s3_api.upload_df(lockdown_data, f'lockdown_data/{filename}', S3Api.S3Location.RAW_DATA)
        print('Successfully uploaded')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()
    lockdown_data_instance = GlobalCovidLockdownData(FileStorage(), S3Api.S3Api())

    print('Retrieving lockdown data from api')
    lockdown_data_instance.retrieve_lockdown_data()

    if STORE_DATA:
        print('Storing raw lockdown data results in S3')
        lockdown_data_instance.store_raw_data()
