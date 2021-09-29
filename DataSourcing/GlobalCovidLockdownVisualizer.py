import pandas as pd
import plotly.express as px
import s3
import codecs

class GlobalCovidLockdownVisualizer:

    def __init__(self, file_storage, s3_api):
        self._file_storage = file_storage
        self._lockdown_file_path = f'{self._file_storage.get_raw_base_path()}/lockdown_data/lockdown_data.csv'
        self._s3_api = s3_api

    def visualize_global_lockdowns(self):
        df = pd.read_csv(self._lockdown_file_path)
        df['Location'] = df['Place'] + ', ' + df['Country']
        df[['StartDate', 'EndDate']] = df[['StartDate', 'EndDate']].apply(pd.to_datetime)
        df['Length'] = (df['EndDate'] - df['StartDate']).dt.days
        fig = px.timeline(df, x_start="StartDate", x_end="EndDate", y="Location", color="Length")
        fig.update_yaxes(autorange="reversed")
        fig.show()
        print('Saving visualizations to folder')
        fig.write_html("raw_data_visualizations/lockdown_data/global_lockdown_data.html")

    def visualize_us_lockdowns(self):
        df = pd.read_csv(self._lockdown_file_path)
        df = df[(df['Country'] == 'United States') & (df['Confirmed'])]
        print(df)
        df['Location'] = df['Place'] + ', ' + df['Country']
        df[['StartDate', 'EndDate']] = df[['StartDate', 'EndDate']].apply(pd.to_datetime)
        df['Length'] = (df['EndDate'] - df['StartDate']).dt.days
        fig = px.timeline(df, x_start="StartDate", x_end="EndDate", y="Location", color="Length")
        fig.update_yaxes(autorange="reversed")
        fig.show()
        print('Saving visualizations to folder')
        fig.write_html("raw_data_visualizations/lockdown_data/us_lockdown_data.html")

    def store_visualization(self):
        f = codecs.open("raw_data_visualizations/lockdown_data/global_lockdown_data.html", 'r')
        print('Attempting to upload global lockdown data html')
        self._s3_api.upload_html(f.read(), 'lockdown_data/global_lockdown_data.html', s3.S3_Location.RAW_DATA_VISUALIZATIONS)

        f = codecs.open("raw_data_visualizations/lockdown_data/us_lockdown_data.html", 'r')
        print('Attempting to upload US lockdown data html')
        self._s3_api.upload_html(f.read(), 'lockdown_data/us_lockdown_data.html', s3.S3_Location.RAW_DATA_VISUALIZATIONS)


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()
    GlobalCovidLockdownVisualizer(FileStorage(), s3.S3_API()).visualize_global_lockdowns()
    GlobalCovidLockdownVisualizer(FileStorage(), s3.S3_API()).visualize_us_lockdowns()
    GlobalCovidLockdownVisualizer(FileStorage(), s3.S3_API()).store_visualization()