import numpy as np
from sklearn.feature_extraction.text import CountVectorizer
import json
import pprint
from FileStorage import FileStorage
import re

class TextDataProcessor:

    def __init__(self, file_storage):
        self.file_storage = file_storage

    def preprocess_text(self, text):
        text = text.lower()
        text = re.sub(r'\d+', '', text)
        return text

    def parse_text_data(self):
        text_data_file = 'raw_data/raw_search_results/scraped_text_results.json'

        with open(text_data_file, 'r') as f:
            data = json.load(f)
            text_data = np.array([item['text'] for item in data])
            vectorizer = CountVectorizer(stop_words='english', preprocessor=self.preprocess_text)
            number_of_words = 200
            v = vectorizer.fit_transform(text_data)
            vocabulary = vectorizer.get_feature_names()
            ind = np.argsort(v.toarray().sum(axis=0))[-number_of_words:]
            top_n_words = [vocabulary[a] for a in ind]

            results = [{ 'text': str(word), 'value': int(count) } for word, count in zip(top_n_words, ind)]
            pprint.pprint(results)

            formatted_contents = json.dumps(results, indent=4, sort_keys=True)
            self.file_storage.store_as_processed_file('search_results/text_breakdowns.json', formatted_contents)


if __name__ == '__main__':
    TextDataProcessor(FileStorage()).parse_text_data()