from newsapi import NewsApiClient
from s3 import S3_API
import os

class NewsApi:

    def __init__(self):
        self.s3_api = S3_API()
        self._api_key = os.environ.get('API_KEY')
        self.news_api = NewsApiClient(api_key=self._api_key)

    def retrieve_news_based_on_query(self, query):
        news = self.news_api.get_everything(
            q=query,
            language='en')

        return news

    def store(self, news):
        self.s3_api.upload_news(news)
        print('Storing information to AWS S3')

