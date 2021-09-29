import pandas as pd
from wordcloud import WordCloud, STOPWORDS, ImageColorGenerator
import matplotlib.pyplot as plt
import S3Api

STORE_DATA = False

class CustomSearchProcessedDataVisualizer:
    """Visualizes processed search data information obtained from the Google Search API using a wordcloud"""

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the CustomSearchDataVisualizer class

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

    def visualize_processed_search_data(self, input_file_path, output_file_path):
        """ Visualizes the processed search data

        Parameters
        ----------
        :param input_file_path: String, Required
            The path to the input file containing the processed vectorized search data
        :param output_file_path: String, Required
            The path to the output file to write the processed data visualization

        ----------
        """
        df = pd.read_csv(input_file_path)
        frequencies = df.T.sum(axis=1)
        wordcloud = WordCloud(stopwords=STOPWORDS, background_color="white").generate_from_frequencies(frequencies)
        plt.figure()
        plt.imshow(wordcloud, interpolation="bilinear")
        plt.axis("off")
        plt.show()
        print('Saving image to file')
        # Save as an svg for scaling purposes
        wordcloud_svg = wordcloud.to_svg(embed_font=True)
        f = open(output_file_path, "w+")
        f.write(wordcloud_svg)
        f.close()

    def store_visualized_data(self, file_path):
        """Stores the processed visualization in S3

        Parameters
        ----------
        :param file_path: String, Required
            The file path where the processed search result visualizations are stored

        ----------
        """
        file = f'{self._file_storage.get_processed_visualizations_base_path()}/{file_path}'
        print('Processing and storing in s3', file)
        svg = open(file, "rb")
        print('Attempting to upload processed visualized search data to s3')
        self._s3_api.upload_svg(svg, file_path, S3Api.S3Location.PROCESSED_DATA_VISUALIZATIONS)
        print('Successfully uploaded')


if __name__ == '__main__':
    from FileStorage import FileStorage
    from dotenv import load_dotenv
    load_dotenv()
    FileStorage().create_directory_if_not_exists('processed_data_visualizations/search_results/')

    search_data_visualizer = CustomSearchProcessedDataVisualizer(FileStorage(), S3Api.S3Api())

    print('Visualizing covid search results using a wordcloud')
    search_data_visualizer.visualize_processed_search_data(
        input_file_path='../processed_data/search_results/covid-search-results.csv',
        output_file_path='../processed_data_visualizations/search_results/covid-search-results.svg')

    print('Visualizing h1n1 search results using a wordcloud')
    search_data_visualizer.visualize_processed_search_data(
        input_file_path='../processed_data/search_results/h1n1-search-results.csv',
        output_file_path='../processed_data_visualizations/search_results/h1n1-search-results.svg')

    if STORE_DATA:
        print('Storing visualized covid search results in S3')
        search_data_visualizer.store_visualized_data('search_results/covid-search-results.svg')

        print('Storing visualized h1n1 search results in S3')
        search_data_visualizer.store_visualized_data('search_results/h1n1-search-results.svg')