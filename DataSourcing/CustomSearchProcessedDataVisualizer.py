import pandas as pd
from wordcloud import WordCloud, STOPWORDS, ImageColorGenerator
import matplotlib.pyplot as plt
import s3

class CustomSearchProcessedDataVisualizer:

    def __init__(self, file_storage, s3_api):
        self._file_storage = file_storage
        self._s3_api = s3_api

    def visualize_processed_search_data(self, input_file_path, output_file_path):
        df = pd.read_csv(input_file_path)
        frequencies = df.T.sum(axis=1)
        wordcloud = WordCloud(stopwords=STOPWORDS, background_color="white").generate_from_frequencies(frequencies)
        plt.figure()
        plt.imshow(wordcloud, interpolation="bilinear")
        plt.axis("off")
        plt.show()
        print('Saving image to file')
        wordcloud_svg = wordcloud.to_svg(embed_font=True)
        f = open(output_file_path, "w+")
        f.write(wordcloud_svg)
        f.close()

    def store_visualized_data(self, file_path):
        file = f'{self._file_storage.get_processed_visualizations_base_path()}/{file_path}'
        print('Processing and storing in s3', file)
        svg = open(file, "rb")
        print('Attempting to upload processed visualized search data to s3')
        self._s3_api.upload_svg(svg, file_path, s3.S3_Location.PROCESSED_DATA_VISUALIZATIONS)
        print('Successfully uploaded')


if __name__ == '__main__':
    from FileStorage import FileStorage
    from dotenv import load_dotenv
    file_storage = FileStorage()
    file_storage.create_directory_if_not_exists('processed_data_visualizations/search_results/')
    load_dotenv()

    search_data_visualizer = CustomSearchProcessedDataVisualizer(FileStorage(), s3.S3_API())

    print('Visualizing covid search results using a wordcloud')
    search_data_visualizer.visualize_processed_search_data(
        input_file_path='processed_data/search_results/covid-search-results.csv',
        output_file_path='processed_data_visualizations/search_results/covid-search-results.svg')

    print('Visualizing h1n1 search results using a wordcloud')
    search_data_visualizer.visualize_processed_search_data(
        input_file_path='processed_data/search_results/h1n1-search-results.csv',
        output_file_path='processed_data_visualizations/search_results/h1n1-search-results.svg')

    print('Storing visualized covid search results in S3')
    search_data_visualizer.store_visualized_data('search_results/covid-search-results.svg')

    print('Storing visualized h1n1 search results in S3')
    search_data_visualizer.store_visualized_data('search_results/h1n1-search-results.svg')