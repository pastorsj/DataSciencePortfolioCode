import numpy as np
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.feature_extraction import text
from nltk.stem import WordNetLemmatizer
import nltk
import json
import pandas as pd
import s3

words = set(nltk.corpus.words.words())
lemmatizer = WordNetLemmatizer()

class CustomSearchDataProcessor:

    def __init__(self, file_storage, s3_api):
        self._file_storage = file_storage
        self._s3_api = s3_api
        self._additional_stop_words = ['title', 'journal', 'volume', 'author', 'scholar', 'article', 'issue']

    def filterNonEnglishWords(self, corpus):
        """
        Partial credit goes to this Stackoverflow answer
        https://stackoverflow.com/questions/41290028/removing-non-english-words-from-text-using-python
        :param text: The corpus of text
        :return: A corpus of text without non-english words
        """

        filtered_vocabulary = " ".join(lemmatizer.lemmatize(w.lower()) for w in nltk.wordpunct_tokenize(corpus) if w.lower() in words)
        return filtered_vocabulary


    def parse_text_data(self, input_file_path, output_file_path):
        stop_words = text.ENGLISH_STOP_WORDS.union(self._additional_stop_words)

        with open(input_file_path, 'r') as f:
            data = json.load(f)

            print('Cleaning and vectorizing data')
            text_data = np.array([self.filterNonEnglishWords(item['text']) for item in data])
            vectorizer = CountVectorizer(stop_words=stop_words)
            v = vectorizer.fit_transform(text_data)
            vocab = vectorizer.get_feature_names()
            values = v.toarray()
            df = pd.DataFrame(values, columns=vocab)
            print(df.head())
            print('Saving processed data to file')
            df.to_csv(output_file_path, index=False)

    def store_processed_data(self, file_path):
        file = f'{self._file_storage.get_processed_base_path()}/{file_path}'
        print('Processing and storing in s3', file)
        df = pd.read_csv(file)
        print('Attempting to upload processed search data to s3')
        self._s3_api.upload_df(df, file_path, s3.S3_Location.PROCESSED_DATA)
        print('Successfully uploaded')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()
    search_data = CustomSearchDataProcessor(FileStorage(), s3.S3_API())

    print('Processing covid search result data')
    search_data.parse_text_data(
        input_file_path='raw_data/search_results/covid-search-results.json',
        output_file_path='processed_data/search_results/covid-search-results.csv')

    print('Processing h1n1 search result data')
    search_data.parse_text_data(
        input_file_path='raw_data/search_results/h1n1-search-results.json',
        output_file_path='processed_data/search_results/h1n1-search-results.csv')

    print('Storing covid search results in S3')
    search_data.store_processed_data('search_results/covid-search-results.csv')

    print('Storing h1n1 search results in S3')
    search_data.store_processed_data('search_results/h1n1-search-results.csv')