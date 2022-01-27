import S3Api
import requests
import pandas as pd
import urllib
import datetime
import matplotlib.pyplot as plt


class NoaaDataSourcing:

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
        self._noaa_summaries_endpoint = 'https://www.ncei.noaa.gov'
        self.version_date = 'v1.0.0-20220108'
        self._file_storage = file_storage
        self._s3_api = s3_api
        self._file_storage.create_directory_if_not_exists('raw_data_visualizations/noaa/')

    def source_noaa_data(self):
        self.retrieve_daily_summary_data()
        self.retrieve_climate_division_data()

    def retrieve_daily_summary_data(self):
        stations_response = requests.get(f'{self._noaa_summaries_endpoint}/data/daily-summaries/doc/ghcnd-stations.txt')
        self._file_storage.store_as_file('noaa/ghcnd-stations.txt', stations_response.text)
        df = pd.read_fwf('raw_data/noaa/ghcnd-stations.txt', widths=[12, 9, 10, 7, 3, 31])
        df.columns = ['StationID', 'Latitude', 'Longitude', 'Elevation', 'State', 'Name']
        us_df = df[df['StationID'].str.startswith('US1') & (df['State'].isin(['DC', 'MD', 'VA']))]
        print(us_df)
        self._file_storage.store_df_as_file('noaa/filtered_ghcnd_stations.csv', df)
        print('Retrieving daily summaries')
        for station in us_df['StationID']:
            print('Retrieving information for station', station)
            try:
                station_df = pd.read_csv(f'{self._noaa_summaries_endpoint}/data/daily-summaries/access/{station}.csv')
                self._file_storage.store_df_as_file(f'noaa/daily_summaries/{station}_data.csv', station_df)
                print('Retrieved and saved info locally.')
            except urllib.error.HTTPError:
                print('Failed to retrieve station info', station)

        print('Retrieving daily normals')
        for station in us_df['StationID']:
            print('Retrieving information for station', station)
            try:
                station_df = pd.read_csv(f'{self._noaa_summaries_endpoint}/access/{station}.csv')
                self._file_storage.store_df_as_file(f'noaa/daily_summaries/{station}_data.csv', station_df)
                print('Retrieved and saved info locally.')
            except urllib.error.HTTPError:
                print('Failed to retrieve station info', station)

    def retrieve_climate_division_data(self):
        print('Sourcing climate division data')
        cd_data_files = [f'climdiv-cddcst-{self.version_date}',
                         f'climdiv-hddcst-{self.version_date}',
                         f'climdiv-pcpnst-{self.version_date}',
                         f'climdiv-pdsist-{self.version_date}',
                         f'climdiv-phdist-{self.version_date}',
                         f'climdiv-pmdist-{self.version_date}',
                         f'climdiv-sp01st-{self.version_date}',
                         f'climdiv-sp02st-{self.version_date}',
                         f'climdiv-sp03st-{self.version_date}',
                         f'climdiv-sp06st-{self.version_date}',
                         f'climdiv-sp09st-{self.version_date}',
                         f'climdiv-sp12st-{self.version_date}',
                         f'climdiv-sp24st-{self.version_date}',
                         f'climdiv-tmaxst-{self.version_date}',
                         f'climdiv-tminst-{self.version_date}',
                         f'climdiv-tmpcst-{self.version_date}',
                         f'climdiv-zndxst-{self.version_date}']

        for cd_file in cd_data_files:
            cd_df = pd.read_fwf(f'{self._noaa_summaries_endpoint}/pub/data/cirs/climdiv/{cd_file}', widths=[3, 1, 2, 4, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7], header=None)
            cd_df.columns = ['State', 'Division', 'Element', 'Year', 'January', 'February', 'March', 'April', 'May', "June", 'July', 'August', 'September', 'October', 'November', 'December']
            print(cd_df.head())
            self._file_storage.store_df_as_file(f'noaa/climate_division/{cd_file}_data.csv', cd_df)

    def visualize_noaa_data(self):
        max_temp_df = pd.read_csv('raw_data/noaa/climate_division/climdiv-tmaxst-v1.0.0-20220108_data.csv')
        max_temp_df = max_temp_df[max_temp_df['State'] == 4]
        max_temp_df = max_temp_df.melt(id_vars=['State', 'Division', 'Element', 'Year'],
                                       var_name='Month',
                                       value_name='MaxTemperature')
        max_temp_df['Month'] = max_temp_df['Month'].apply(lambda x: datetime.datetime.strptime(x, "%B").month)
        max_temp_df['DATE'] = pd.to_datetime(max_temp_df[['Year', 'Month']].assign(DAY=1))
        max_temp_df = max_temp_df.sort_values(by=['DATE'])
        print(max_temp_df)

        plt.figure()
        plt.plot(max_temp_df['DATE'], max_temp_df['MaxTemperature'], color="red")
        plt.xlabel('Time')
        plt.xticks([])
        plt.ylabel('Max Temperature')
        plt.title('Max Temperature over Time in California')
        plt.savefig('raw_data_visualizations/noaa/temp_over_time.svg', format='svg')
        plt.savefig('raw_data_visualizations/noaa/temp_over_time.png')
        plt.show()


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage

    load_dotenv()

    noaa_data_sourcing_instance = NoaaDataSourcing(FileStorage(), S3Api.S3Api())

    print('Retrieving raw noaa data')
    noaa_data_sourcing_instance.visualize_noaa_data()
