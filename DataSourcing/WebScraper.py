import json
import pprint
import requests
from readability import Document
import html2text
from FileStorage import FileStorage

class WebScraper:

    def __init__(self, file_storage):
        self.file_storage = file_storage

    def scrape_google_results(self):
        search_results_file = f'{self.file_storage.get_raw_base_path()}/raw_search_results/search-results.json'
        text_results = []
        with open(search_results_file, 'r') as f:
            search_results = json.load(f)
            for result in search_results:
                if 'mime' in result and 'application/pdf' in result['mime']:
                    continue
                response = requests.get(result['link'])
                doc = Document(response.text)
                print(result['link'])
                summary_of_article = doc.summary()
                print(doc.title())
                print(html2text.html2text(summary_of_article))
                text_results.append({
                    'link': result['link'],
                    'title': doc.title(),
                    'text': html2text.html2text(summary_of_article)
                })

            formatted_contents = json.dumps(text_results, indent=4, sort_keys=True)
            self.file_storage.store_as_file('raw_search_results/scraped_text_results.json', formatted_contents)






if __name__ == '__main__':
    WebScraper(FileStorage()).scrape_google_results()