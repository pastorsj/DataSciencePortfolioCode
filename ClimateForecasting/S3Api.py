import boto3
import json
import os
from io import StringIO
from enum import Enum


class S3Location(Enum):
    RAW_DATA = 'raw_data'
    RAW_DATA_VISUALIZATIONS = 'raw_data_visualizations'
    CLEANED_DATA = 'cleaned_data'
    CLEANED_DATA_VISUALIZATIONS = 'cleaned_data_visualizations'
    EDA_VISUALIZATIONS = 'eda_visualizations'
    ARMA_VISUALIZATIONS = 'arma_visualizations'
    ARMA_DATA = 'arma_data'


class S3Api:
    """
    The S3 API used to store raw data, raw data visualizations, processed data, and
    processed data visualizations in AWS S3.

    S3 Bucket Structure

    raw_data/
    raw_data_visualizations/
    """

    def __init__(self):
        """ Create a new instance of the S3Api class"""
        self._s3_bucket = os.environ.get('S3_BUCKET')
        self._s3 = boto3.resource('s3')

    def upload_df(self, df, file_name, location):
        """Uploads a dataframe to S3

        Parameters
        ----------
        :param df: pd.DataFrame, Required
            A pandas dataframe
        :param file_name: String, Required
            The name of the file used in S3
        :param location: S3Location, Required
            The directory where the file will be stored

        ----------
        """
        csv_buffer = StringIO()
        df.to_csv(csv_buffer, index=False)
        s3_object = self._s3.Object(self._s3_bucket, f'{location.value}/{file_name}')
        s3_object.put(Body=csv_buffer.getvalue())

    def upload_html(self, html, file_name, location):
        """Uploads an html file to S3

        Parameters
        ----------
        :param html: String, Required
            An html file, usually a visualization, but can be any raw html string
        :param file_name: String, Required
            The name of the file used in S3
        :param location: S3Location, Required
            The directory where the file will be stored

        ----------
        """
        s3_object = self._s3.Object(self._s3_bucket, f'{location.value}/{file_name}')
        s3_object.put(Body=html, ContentType='text/html')

    def upload_json(self, json_data, file_name, location):
        """Uploads an json file to S3

        Parameters
        ----------
        :param json_data: Dictionary, Required
            An json object, typically represented as a Dictionary
        :param file_name: String, Required
            The name of the file used in S3
        :param location: S3Location, Required
            The directory where the file will be stored

        ----------
        """
        s3_object = self._s3.Object(self._s3_bucket, f'{location.value}/{file_name}')
        s3_object.put(Body=bytes(json.dumps(json_data).encode('utf-8')))

    def upload_svg(self, svg, file_name, location):
        """Uploads an svg to S3

        Parameters
        ----------
        :param svg: bytes, Required
            An svg file, typically in the bytes format
        :param file_name: String, Required
            The name of the file used in S3
        :param location: S3Location, Required
            The directory where the file will be stored

        ----------
        """
        s3_object = self._s3.Object(self._s3_bucket, f'{location.value}/{file_name}')
        s3_object.put(Body=svg, ContentType='image/svg+xml')

    def upload_bytes(self, content, file_name, location):
        s3_object = self._s3.Object(self._s3_bucket, f'{location.value}/{file_name}')
        s3_object.put(Body=content)

    def upload_png(self, png, file_name, location):
        s3_object = self._s3.Object(self._s3_bucket, f'{location.value}/{file_name}')
        s3_object.put(Body=png, ContentType='image/png')

    def upload_gif(self, gif, file_name, location):
        s3_object = self._s3.Object(self._s3_bucket, f'{location.value}/{file_name}')
        s3_object.put(Body=gif, ContentType='image/gif')