from wordcloud import WordCloud, STOPWORDS, ImageColorGenerator
import json
import matplotlib.pyplot as plt
import S3Api

# Constants
STORE_DATA = False


class CustomSearchDataVisualizer:
    """Visualizes raw search data information obtained from the Google Search API using a wordcloud"""

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the CustomSearchDataVisualizer class

        Parameters
        ----------
        :param file_storage: FileStorage, Required
            The file storage class used to store raw/processed data
        :param s3_api: S3_API, Required
            The S3 api wrapper class used to store data in AWS S3

        ----------
        """
        self._file_storage = file_storage
        self._s3_api = s3_api

    def visualize_raw_search_data(self, input_file_path, output_file_path):
        """ Visualizes the raw search data

        Parameters
        ----------
        :param input_file_path: String, Required
            The path to the input file containing a corpus of text
        :param output_file_path: String, Required
            The path to the output file to write the raw data visualization

        ----------
        """
        with open(input_file_path, 'r') as f:
            data = json.load(f)
            text_data = " ".join([item['text'] for item in data])
            print(len(text_data))
            # Create a wordcloud of the raw text data with basic stopwords removed
            wordcloud = WordCloud(stopwords=STOPWORDS, background_color="white").generate(text_data)
            plt.figure()
            plt.imshow(wordcloud, interpolation="bilinear")
            plt.axis("off")
            plt.show()
            print('Saving image to file')
            wordcloud_svg = wordcloud.to_svg(embed_font=True)
            fp = open(output_file_path, "w+")
            fp.write(wordcloud_svg)
            fp.close()

    def store_visualized_data(self, file_path):
        """Stores the raw visualization in S3

        Parameters
        ----------
        :param file_path: String, Required
            The file path where the raw search result visualizations are stored

        ----------
        """
        file = f'{self._file_storage.get_raw_visualizations_base_path()}/{file_path}'
        print('Processing and storing in s3', file)
        svg = open(file, "rb")
        print('Attempting to upload raw visualized search data to s3')
        self._s3_api.upload_svg(svg, file_path, S3Api.S3Location.RAW_DATA_VISUALIZATIONS)
        print('Successfully uploaded')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()
    search_data_visualizer = CustomSearchDataVisualizer(FileStorage(), S3Api.S3Api())

    print('Visualizing covid search results using a wordcloud')
    search_data_visualizer.visualize_raw_search_data(
        input_file_path='../raw_data/search_results/covid-search-results.json',
        output_file_path='../raw_data_visualizations/search_results/covid-search-results.svg')

    print('Visualizing h1n1 search results using a wordcloud')
    search_data_visualizer.visualize_raw_search_data()

    if STORE_DATA:
        print('Storing visualized covid search results in S3')
        search_data_visualizer.store_visualized_data('search_results/covid-search-results.svg')

        print('Storing visualized h1n1 search results in S3')
        search_data_visualizer.store_visualized_data('search_results/h1n1-search-results.svg')