from googleapiclient.discovery import build
import json
import requests
from readability import Document
import html2text
import S3Api

# Constants
STORE_DATA = False


class CustomSearchData:
    """Retrieves search data information from the Google Search API"""

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the CustomSearchData class

        Parameters
        ----------
        :param file_storage: FileStorage, Required
            The file storage class used to store raw/processed data
        :param s3_api: S3_API, Required
            The S3 api wrapper class used to store data in AWS S#

        ----------
        """
        self._file_storage = file_storage
        self._s3_api = s3_api

    def search(self, number_of_queries, query, file_path):
        """Utilizes the Google Search API to search for data given a query

        Parameters
        ----------
        :param number_of_queries: Number, Required
            The number of queries to run against the Google Search API
        :param query: String, Required
            The query to run against the Google Search API
        :param file_path: String, Required
            The file path where the raw search results are stored

        ----------
        """
        results = []
        print(f'Retrieving {number_of_queries} items from google search')
        for i in range(0, number_of_queries, 10):
            print('Searching for the next page of results', i)
            service = build("customsearch", "v1",
                            developerKey="AIzaSyAuaNlegnLXnaFJLP4Pg9c7BJ2Rwn_hGsE")
            res = service.cse().list(
                q=query,
                cx='fd5f83557fa04f383',
                start=i
            ).execute()
            print('Retrieved the results from the current page')
            results += res['items']

        print('Scraping websites for data')
        self.scrape_google_results(results, file_path)

    def scrape_google_results(self, search_results, file_path):
        """Scrapes the websites that are returned from the Google Search API for text data

        Parameters
        ----------
        :param search_results: Dictionary, Required
            The search results from the Google Search API
        :param file_path: String, Required
            The file path where the raw search results are stored

        ----------
        """
        text_results = []
        for result in search_results:
            if 'mime' in result and 'application/pdf' in result['mime']:
                continue
            print('Scraping results from this link', result['link'])
            try:
                response = requests.get(result['link'], timeout=15)
                doc = Document(response.text)
                summary_of_article = doc.summary()
                print(doc.title())
                text_results.append({
                    'link': result['link'],
                    'title': doc.title(),
                    'text': html2text.html2text(summary_of_article)
                })
                print('Appended information to results')
            except Exception as error:
                print('&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&')
                print('An error occurred while processing a document. Skipping...')
                print(error)
                print('&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&')
                continue

        print('Scraped together', len(text_results), 'websites for information.')
        formatted_contents = json.dumps(text_results, indent=4, sort_keys=True)
        self._file_storage.store_as_file(file_path, formatted_contents)

    def store_raw_data(self, file_path):
        """Stores the raw data in S3

        Parameters
        ----------
        :param file_path: String, Required
            The file path where the raw search results are stored

        ----------
        """
        file = f'{self._file_storage.get_raw_base_path()}/{file_path}'
        print('Processing and storing in s3', file)
        fp = open(file, "r")
        search_data = json.load(fp)
        print('Attempting to upload raw search data to s3')
        self._s3_api.upload_json(search_data, file_path, S3Api.S3Location.RAW_DATA)
        print('Successfully uploaded')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()
    search_data_instance = CustomSearchData(FileStorage(), S3Api.S3Api())
    print('Scraping the google search api for covid 19 articles relating to food security')
    search_data_instance.search(40, 'covid covid19 food security hunger', 'search_results/covid-search-results.json')

    print('Scraping the google search api for h1n1 articles relating to food security')
    search_data_instance.search(40, 'h1n1 food security hunger', 'search_results/h1n1-search-results.json')

    if STORE_DATA:
        print('Storing covid search results in S3')
        search_data_instance.store_raw_data('search_results/covid-search-results.json')

        print('Storing h1n1 search results in S3')
        search_data_instance.store_raw_data('search_results/h1n1-search-results.json')

