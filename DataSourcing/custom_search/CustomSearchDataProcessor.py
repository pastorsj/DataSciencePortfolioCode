import numpy as np
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.feature_extraction import text
from nltk.stem import WordNetLemmatizer
import nltk
import json
import pandas as pd
import S3Api

# Constants
STORE_DATA = False
words = set(nltk.corpus.words.words())
lemmatizer = WordNetLemmatizer()


class CustomSearchDataProcessor:
    """Processes search data information from the Google Search API"""

    def __init__(self, file_storage, s3_api):
        self._file_storage = file_storage
        self._s3_api = s3_api
        self._additional_stop_words = ['title', 'journal', 'volume', 'author', 'scholar', 'article', 'issue']

    def filter_non_english_words(self, corpus):
        """ Filters, lowercases, and lemmatizes non english words using the nltk word list.
        Partial credit goes to this Stackoverflow answer
        https://stackoverflow.com/questions/41290028/removing-non-english-words-from-text-using-python


        Parameters
        ----------
        :param corpus: String, Required
            The corpus of text

        ----------

        Returns
        -------
        :return: String
            A corpus of text without non-english words

        -------
        """

        filtered_vocabulary = " ".join(lemmatizer.lemmatize(w.lower()) for w in nltk.wordpunct_tokenize(corpus) if w.lower() in words)
        return filtered_vocabulary

    def parse_text_data(self, input_file_path, output_file_path):
        """ Parses the text data and saves the output as a dataframe in a csv

        Parameters
        ----------
        :param input_file_path: String, Required
            The path to the input file containing a corpus of text
        :param output_file_path: String, Required
            The path to the output file to write the processed data

        ----------
        """
        stop_words = text.ENGLISH_STOP_WORDS.union(self._additional_stop_words)

        with open(input_file_path, 'r') as f:
            data = json.load(f)

            print('Cleaning and vectorizing data')
            text_data = np.array([self.filter_non_english_words(item['text']) for item in data])
            # Using the CountVectorizer class to remove stop words and vectorize text data
            vectorizer = CountVectorizer(stop_words=stop_words)
            v = vectorizer.fit_transform(text_data)
            vocab = vectorizer.get_feature_names()
            values = v.toarray()
            df = pd.DataFrame(values, columns=vocab)
            print(df.head())
            print('Saving processed data to file')
            df.to_csv(output_file_path, index=False)

    def store_processed_data(self, file_path):
        """Stores the processed data in S3

        Parameters
        ----------
        :param file_path: String, Required
            The file path where the processed search results are stored

        ----------
        """
        file = f'{self._file_storage.get_processed_base_path()}/{file_path}'
        print('Processing and storing in s3', file)
        df = pd.read_csv(file)
        print('Attempting to upload processed search data to s3')
        self._s3_api.upload_df(df, file_path, S3Api.S3Location.PROCESSED_DATA)
        print('Successfully uploaded')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()
    search_data = CustomSearchDataProcessor(FileStorage(), S3Api.S3Api())

    print('Processing covid search result data')
    search_data.parse_text_data(
        input_file_path='../raw_data/search_results/covid-search-results.json',
        output_file_path='../processed_data/search_results/covid-search-results.csv')

    print('Processing h1n1 search result data')
    search_data.parse_text_data(
        input_file_path='../raw_data/search_results/h1n1-search-results.json',
        output_file_path='../processed_data/search_results/h1n1-search-results.csv')

    if STORE_DATA:
        print('Storing covid search results in S3')
        search_data.store_processed_data('search_results/covid-search-results.csv')

        print('Storing h1n1 search results in S3')
        search_data.store_processed_data('search_results/h1n1-search-results.csv')