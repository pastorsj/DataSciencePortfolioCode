import plotly.express as px
import pandas as pd
import os
import S3Api
import us
import glob
import codecs


STORE_DATA = False

class HouseholdSurveysProcessedDataVisualizer:

    def __init__(self, file_storage, s3_api):
        self._file_storage = file_storage
        self._s3_api = s3_api

    def visualize_processed_data(self, input_file_path, output_file_path):
        self._file_storage.create_directory_if_not_exists(output_file_path)
        for f in [file for file in os.listdir(input_file_path) if 'normalized' not in file]:
            state = f.replace('.csv', '')
            input_file = f'{input_file_path}/{state}.csv'
            df = pd.read_csv(input_file)
            df = df[df['Topic'] == 'total']
            df['Date'] = pd.to_datetime(df['Date'])
            df = df.sort_values(by='Date')
            full_state = us.states.lookup(state).name
            fig = px.line(df, x='Date', y=df.columns[4:-2], title=f'Household Survey Data for {full_state}', labels={
                'value': 'Total (persons)',
                'variable': 'Survey Question'
            })

            output_file = f'{output_file_path}{state}.html'
            print('Saving visualizations to folder', output_file)
            fig.write_html(output_file)

    def store_survey_data(self):
        print('Store processed survey data in S3')

        processed_files = list(glob.iglob('processed_data_visualizations/survey_data/**/*.html', recursive=True))
        for file in processed_files:
            print('Opening file', file)
            contents = codecs.open(file, 'r')
            print('Uploading', file, 'to S3')
            self._s3_api.upload_html(contents.read(), file.replace('processed_data_visualizations/', ''), S3Api.S3Location.PROCESSED_DATA_VISUALIZATIONS)
            contents.close()

        print('Uploaded all files')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()
    data_visualizer = HouseholdSurveysProcessedDataVisualizer(FileStorage(), S3Api.S3Api())

    print('Visualizing standard household survey data')
    data_visualizer.visualize_processed_data(
        input_file_path='processed_data/consolidated_survey_data/standard/all',
        output_file_path='processed_data_visualizations/survey_data/all/')

    print('Visualizing household survey data when families have children')
    data_visualizer.visualize_processed_data(
        input_file_path='processed_data/consolidated_survey_data/standard/children',
        output_file_path='processed_data_visualizations/survey_data/children/')

    if STORE_DATA:
        print('Storing processed survey data visualizations')
        data_visualizer.store_survey_data()
