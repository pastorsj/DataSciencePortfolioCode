import S3Api
import requests
import pandas as pd
import urllib
import matplotlib.pyplot as plt


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
        self._file_storage.create_directory_if_not_exists('raw_data_visualizations/dm/')

    def source_drought_data(self):
        states = ','.join([f'{i}'.zfill(2) for i in range(1, 51)])

        print('Retrieving drought data as a percent of area')
        drought_response_df = pd.read_json(
            f'{self.drought_monitor_endpoint}/GetDroughtSeverityStatisticsByAreaPercent?aoi={states}&startdate=1/1/2000&enddate=1/1/2022&statisticsType=1')
        print(drought_response_df)
        self._file_storage.store_df_as_file('dm/dm_statistics_percent_area.csv', drought_response_df)

        print('Retrieving drought data as a percent of population')
        drought_response_df = pd.read_json(
            f'{self.drought_monitor_endpoint}/GetDroughtSeverityStatisticsByPopulationPercent?aoi={states}&startdate=1/1/2000&enddate=1/1/2022&statisticsType=1')
        print(drought_response_df)
        self._file_storage.store_df_as_file('dm/dm_statistics_percent_population.csv', drought_response_df)

    def visualize_drought_data(self):
        drought_data_df = pd.read_csv('raw_data/dm/dm_statistics_percent_area.csv')
        drought_data_ca_df = drought_data_df[drought_data_df['StateAbbreviation'] == 'CA']
        print(drought_data_ca_df)
        plt.figure()
        fig, axs = plt.subplots(2, 2)
        fig.set_figheight(8)
        fig.set_figwidth(12)
        axs[0, 0].plot(drought_data_ca_df['ValidStart'], drought_data_ca_df['D1'], color="orange")
        axs[0, 0].set_xlabel('Date (2000-Present)')
        axs[0, 0].set_ylabel('D1 Drought Status (%)')
        axs[0, 0].set_xticks([])
        axs[0, 0].set_title('Drought in California (D1 Status)')

        axs[0, 1].plot(drought_data_ca_df['ValidStart'], drought_data_ca_df['D2'], color="orange")
        axs[0, 1].set_xlabel('Date (2000-Present)')
        axs[0, 1].set_ylabel('D2 Drought Status (%)')
        axs[0, 1].set_xticks([])
        axs[0, 1].set_title('Drought in California (D2 Status)')

        axs[1, 0].plot(drought_data_ca_df['ValidStart'], drought_data_ca_df['D3'], color="orange")
        axs[1, 0].set_xlabel('Date (2000-Present)')
        axs[1, 0].set_ylabel('D3 Drought Status (%)')
        axs[1, 0].set_xticks([])
        axs[1, 0].set_title('Drought in California (D3 Status)')

        axs[1, 1].plot(drought_data_ca_df['ValidStart'], drought_data_ca_df['D4'], color="orange")
        axs[1, 1].set_xlabel('Date (2000-Present)')
        axs[1, 1].set_ylabel('D4 Drought Status (%)')
        axs[1, 1].set_xticks([])
        axs[1, 1].set_title('Drought in California (D4 Status)')
        plt.savefig('raw_data_visualizations/dm/drought_in_california.svg', format='svg')
        plt.savefig('raw_data_visualizations/dm/drought_in_california.png')
        plt.show()


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage

    load_dotenv()

    noaa_data_sourcing_instance = UsDroughtMonitor(FileStorage(), S3Api.S3Api())

    print('Retrieving raw noaa data')
    noaa_data_sourcing_instance.visualize_drought_data()
