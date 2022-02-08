import S3Api
import pandas as pd
import plotly.express as px
from bs4 import BeautifulSoup
import requests
import re
import urllib


class UsFloodData:

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the UsFloodData class

        Parameters
        ----------
        :param file_storage: FileStorage, Required
            The file storage class used to store raw/processed data
        :param s3_api: S3_API, Required
            The S3 api wrapper class used to store data in AWS S3

        ----------
        """
        self._file_storage = file_storage
        self._s3_api = s3_api
        self._file_storage.create_directory_if_not_exists('raw_data_visualizations/flood/')
        self._noaa_endpoint = 'https://www.ncei.noaa.gov/data/storm-events/access/original'

    def retrieve_flood_data(self):
        years = range(2006, 2021)
        flood_dfs = []
        for year in years:
            response = requests.get(f'{self._noaa_endpoint}/{year}')
            soup = BeautifulSoup(response.text, 'lxml')
            result = soup.findAll('a', attrs={"href": re.compile(r'StormEvents_details+')})
            result = [r.text.replace('/', '') for r in result]
            for file in result:
                try:
                    print('Retrieving file', f'{self._noaa_endpoint}/{year}/{file}')
                    flood_df = pd.read_csv(f'{self._noaa_endpoint}/{year}/{file}', on_bad_lines='skip')
                    flood_df = flood_df[flood_df['event_type'].isin(['Lakeshore Flood', 'Flood', 'Flash Flood', 'Coastal Flood'])]
                    print(flood_df.head())
                    flood_dfs.append(flood_df)
                    print('Retrieved and saved info locally.')
                except urllib.error.HTTPError:
                    print('Failed to retrieve flood info', file)

        result_df = pd.concat(flood_dfs)
        print(result_df.head())
        print(result_df.shape)
        self._file_storage.store_df_as_file('flood/flood_data.csv', result_df)


    def visualize_raw_flood_data(self):
        flood_df = pd.read_csv('raw_data/flood/USFD_v1.0.csv')
        flood_agg_df = flood_df.groupby(['STATE']).size().reset_index(name='counts')
        fig = px.bar(flood_agg_df,
                     x='STATE',
                     y='counts',
                     title="Recorded Floods across the United States",
                     labels={
                         "STATE": "State",
                         "counts": "Number of Floods"
                     })
        fig.show()
        fig.write_html("raw_data_visualizations/flood/us_floods.html")


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()

    flood_data_sourcing_instance = UsFloodData(FileStorage(), S3Api.S3Api())

    print('Visualizing raw flood data')
    flood_data_sourcing_instance.retrieve_flood_data()

