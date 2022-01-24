import S3Api
import requests
import pandas as pd
import urllib


class UsDroughtMonitor:

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the NoaaDataSourcing class

        Parameters
        ----------
        :param file_storage: FileStorage, Required
            The file storage class used to store raw/processed data
        :param s3_api: S3_API, Required
            The S3 api wrapper class used to store data in AWS S3

        ----------
        """
        self.drought_monitor_endpoint = 'https://usdmdataservices.unl.edu/api/StateStatistics'
        self._file_storage = file_storage
        self._s3_api = s3_api

    def source_drought_data(self):
        states = ','.join([f'{i}'.zfill(2) for i in range(1, 51)])

        print('Retrieving drought data as a percent of area')
        drought_response_df = pd.read_json(f'{self.drought_monitor_endpoint}/GetDroughtSeverityStatisticsByAreaPercent?aoi={states}&startdate=1/1/2000&enddate=1/1/2022&statisticsType=1')
        print(drought_response_df)
        self._file_storage.store_df_as_file('dm/dm_statistics_percent_area.csv', drought_response_df)

        print('Retrieving drought data as a percent of population')
        drought_response_df = pd.read_json(f'{self.drought_monitor_endpoint}/GetDroughtSeverityStatisticsByPopulationPercent?aoi={states}&startdate=1/1/2000&enddate=1/1/2022&statisticsType=1')
        print(drought_response_df)
        self._file_storage.store_df_as_file('dm/dm_statistics_percent_population.csv', drought_response_df)


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()

    noaa_data_sourcing_instance = UsDroughtMonitor(FileStorage(), S3Api.S3Api())

    print('Retrieving raw noaa data')
    noaa_data_sourcing_instance.source_drought_data()

