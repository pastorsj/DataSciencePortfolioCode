import pandas as pd
import plotly.express as px
import S3Api
import codecs

# Constants
STORE_DATA = False

class GlobalCovidLockdownVisualizer:
    """Visualizes the lockdown data using a timeline plot"""

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the GlobalCovidLockdownVisualizer class

        Parameters
        ----------
        :param file_storage: FileStorage, Required
            The file storage class used to store raw/processed data
        :param s3_api: S3_API, Required
            The S3 api wrapper class used to store data in AWS S3

        ----------
        """
        self._file_storage = file_storage
        self._lockdown_file_path = f'{self._file_storage.get_raw_base_path()}/lockdown_data/lockdown_data.csv'
        self._s3_api = s3_api

    def visualize_global_lockdowns(self):
        """Visualizes the global lockdown data using an interactive timeline plot"""
        df = pd.read_csv(self._lockdown_file_path)

        # Preprocess some of the columns for the visualization
        df['Location'] = df['Place'] + ', ' + df['Country']
        df[['StartDate', 'EndDate']] = df[['StartDate', 'EndDate']].apply(pd.to_datetime)
        # Calculate the length of the lockdown for the timeline visualization
        df['Length'] = (df['EndDate'] - df['StartDate']).dt.days

        fig = px.timeline(df, x_start="StartDate", x_end="EndDate", y="Location", color="Length")
        fig.update_yaxes(autorange="reversed")
        fig.show()
        print('Saving visualizations to folder')
        fig.write_html("raw_data_visualizations/lockdown_data/global_lockdown_data.html")

    def visualize_us_lockdowns(self):
        """Visualizes the us lockdown data using an interactive timeline plot"""
        df = pd.read_csv(self._lockdown_file_path)

        # Filter raw dat down to only confirmed United States lockdowns
        df = df[(df['Country'] == 'United States') & (df['Confirmed'])]
        df['Location'] = df['Place'] + ', ' + df['Country']
        df[['StartDate', 'EndDate']] = df[['StartDate', 'EndDate']].apply(pd.to_datetime)
        # Calculate the length of the lockdown for the timeline visualization
        df['Length'] = (df['EndDate'] - df['StartDate']).dt.days

        fig = px.timeline(df, x_start="StartDate", x_end="EndDate", y="Location", color="Length")
        fig.update_yaxes(autorange="reversed")
        fig.show()
        print('Saving visualizations to folder')
        fig.write_html("raw_data_visualizations/lockdown_data/us_lockdown_data.html")

    def store_visualization(self):
        """Stores the raw visualizations in S3"""
        f = codecs.open("../raw_data_visualizations/lockdown_data/global_lockdown_data.html", 'r')
        print('Attempting to upload global lockdown data html')
        self._s3_api.upload_html(f.read(), 'lockdown_data/global_lockdown_data.html', S3Api.S3Location.RAW_DATA_VISUALIZATIONS)

        f = codecs.open("../raw_data_visualizations/lockdown_data/us_lockdown_data.html", 'r')
        print('Attempting to upload US lockdown data html')
        self._s3_api.upload_html(f.read(), 'lockdown_data/us_lockdown_data.html', S3Api.S3Location.RAW_DATA_VISUALIZATIONS)


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()
    lockdown_visualizer_instance = GlobalCovidLockdownVisualizer(FileStorage(), S3Api.S3Api())

    print('Visualizing global lockdowns')
    lockdown_visualizer_instance.visualize_global_lockdowns()

    print('Visualizing US lockdowns')
    lockdown_visualizer_instance.visualize_us_lockdowns()

    if STORE_DATA:
        lockdown_visualizer_instance.store_visualization()