import boto3
import json
import os

class S3_API:

    def __init__(self):
        self._s3_bucket = os.environ.get('S3_BUCKET')
        self._s3 = boto3.resource('s3')

    def upload_news(self, json_data):

        s3_object = self._s3.Object(self._s3_bucket, 'news/news.json')
        s3_object.put(Body=bytes(json.dumps(json_data).encode('utf-8')))