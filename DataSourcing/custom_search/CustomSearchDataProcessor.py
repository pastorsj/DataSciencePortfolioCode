from sklearn.feature_extraction.text import ENGLISH_STOP_WORDS
from nltk.stem import WordNetLemmatizer
import nltk
import pandas as pd
import S3Api
import glob
import statistics

# Constants
STORE_DATA = False
words = set(nltk.corpus.words.words())
lemmatizer = WordNetLemmatizer()


class CustomSearchDataProcessor:
    """Processes search data information from the Google Search API"""

    def __init__(self, file_storage, s3_api):
        self._file_storage = file_storage
        self._s3_api = s3_api
        self._additional_stop_words = ['title', 'journal', 'volume', 'author', 'scholar', 'article', 'issue', 'food',
                                       'hunger', 'people', 'million', 'world', 'security', 'insecurity']
        self._defined_stop_words = set(ENGLISH_STOP_WORDS.union(self._additional_stop_words))

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

        filtered_vocabulary = [lemmatizer.lemmatize(w.lower()) for w in nltk.wordpunct_tokenize(corpus) if w.lower() in words]
        filtered_vocabulary = [w for w in filtered_vocabulary if len(w) > 2 and w not in self._defined_stop_words]
        return " ".join(filtered_vocabulary)

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
        all_files = list(glob.iglob(f'{input_file_path}/*.csv', recursive=True))
        frames = [pd.read_csv(f) for f in all_files]
        search_df = pd.concat(frames)
        print(search_df.shape[0])
        search_df = search_df.drop_duplicates(subset=['link'])
        print(search_df.shape[0])
        print(search_df.columns)

        search_df['text'] = search_df['text'].apply(self.filter_non_english_words)
        print('Stats')
        print('Max length of article', max(search_df['text']))
        print('Min length of article', min(search_df['text'].str.len()))
        print('Mean length of article', statistics.mean(search_df['text'].str.len()))
        print('Median length of article', statistics.median(search_df['text'].str.len()))
        print('Standard Deviation length of article', statistics.stdev(search_df['text'].str.len()))
        lower_bound = 1000
        upper_bound = statistics.mean(search_df['text'].str.len()) + statistics.stdev(search_df['text'].str.len())
        search_df = search_df.loc[(search_df['text'].str.len() > lower_bound) & (search_df['text'].str.len() < upper_bound)]

        print(search_df.head())
        print(search_df.shape[0])
        print('Length of text', len(search_df['text'].to_list()))

        search_df.to_csv(f'{output_file_path}/cleaned_search_data.csv', index=False)

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
        input_file_path='raw_data/search_results',
        output_file_path='processed_data/search_results')

    if STORE_DATA:
        print('Storing covid search results in S3')
        search_data.store_processed_data('search_results/cleaned_search_data.csv')