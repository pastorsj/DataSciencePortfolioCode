from googleapiclient.discovery import build
import pprint
import json
import requests
from readability import Document
import html2text
import os
import s3


class CustomSearchData:
    def __init__(self, file_storage, s3_api):
        self._file_storage = file_storage
        self._s3_api = s3_api

    def search(self, query, filepath):
        results = []
        print('Retrieving 40 items from google search')
        for i in range(0, 40, 10):
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
        self.scrape_google_results(results, filepath)

    def scrape_google_results(self, search_results, filepath):
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
        self._file_storage.store_as_file(filepath, formatted_contents)

    def store_raw_data(self, file_path):
        file = f'{self._file_storage.get_raw_base_path()}/{file_path}'
        print('Processing and storing in s3', file)
        fp = open(file, "r")
        search_data = json.load(fp)
        print('Attempting to upload raw search data to s3')
        self._s3_api.upload_json(search_data, file_path, s3.S3_Location.RAW_DATA)
        print('Successfully uploaded')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()
    search_data = CustomSearchData(FileStorage(), s3.S3_API())
    print('Scraping the google search api for covid 19 articles relating to food security')
    search_data.search('covid covid19 food security hunger', 'search_results/covid-search-results.json')

    print('Scraping the google search api for h1n1 articles relating to food security')
    search_data.search('h1n1 food security hunger', 'search_results/h1n1-search-results.json')

    print('Storing covid search results in S3')
    search_data.store_raw_data('search_results/covid-search-results.json')

    print('Storing h1n1 search results in S3')
    search_data.store_raw_data('search_results/h1n1-search-results.json')

