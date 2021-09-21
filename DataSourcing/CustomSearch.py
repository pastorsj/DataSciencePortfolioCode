from googleapiclient.discovery import build
import pprint
import json
from FileStorage import FileStorage

class CustomSearch:
    def __init__(self, file_storage):
        self.file_storage = file_storage


    def search(self):
        results = []
        for i in range(0, 100, 10):
            service = build("customsearch", "v1",
                            developerKey="AIzaSyAuaNlegnLXnaFJLP4Pg9c7BJ2Rwn_hGsE")
            res = service.cse().list(
                q='covid food security',
                cx='fd5f83557fa04f383',
                start=i
            ).execute()
            results += res['items']

        pprint.pprint(results)
        formatted_contents = json.dumps(results, indent=4, sort_keys=True)
        self.file_storage.store_as_file('raw_search_results/search-results.json', formatted_contents)


if __name__ == '__main__':
    CustomSearch(FileStorage()).search()