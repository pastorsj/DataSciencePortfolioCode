import boto3
import json
import os
from io import StringIO
from enum import Enum


class S3_Location(Enum):
    RAW_DATA = 'raw_data'
    RAW_DATA_VISUALIZATIONS = 'raw_data_visualizations'
    PROCESSED_DATA = 'processed_data'
    PROCESSED_DATA_VISUALIZATIONS = 'processed_data_visualizations'


class S3_API:
    """
    The S3 API used to store raw data, raw data visualizations, processed data, and processed data visualizations

    S3 Bucket Structure

    raw_data/
        lockdown_data/
        raw_search_results/
        survey_data/
        wdi_data/
    raw_data_visualizations/
        lockdown_data/
    processed_data/
        survey_data/
        consolidated_survey_data/
        search_results/
    processed_data_visualizations/
    """

    def __init__(self):
        self._s3_bucket = os.environ.get('S3_BUCKET')
        self._s3 = boto3.resource('s3')

    def upload_df(self, df, file_name, location):
        csv_buffer = StringIO()
        df.to_csv(csv_buffer)
        s3_object = self._s3.Object(self._s3_bucket, f'{location.value}/{file_name}')
        s3_object.put(Body=csv_buffer.getvalue())

    def upload_html(self, html, file_name, location):
        s3_object = self._s3.Object(self._s3_bucket, f'{location.value}/{file_name}')
        s3_object.put(Body=html, ContentType='text/html')

    def upload_json(self, json_data, file_name, location):
        s3_object = self._s3.Object(self._s3_bucket, f'{location.value}/{file_name}')
        s3_object.put(Body=bytes(json.dumps(json_data).encode('utf-8')))

    def upload_svg(self, svg, file_name, location):
        s3_object = self._s3.Object(self._s3_bucket, f'{location.value}/{file_name}')
        s3_object.put(Body=svg, ContentType='image/svg+xml')