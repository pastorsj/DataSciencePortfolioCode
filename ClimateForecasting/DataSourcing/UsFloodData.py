import S3Api
import pandas as pd
import plotly.express as px


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
    flood_data_sourcing_instance.visualize_raw_flood_data()

