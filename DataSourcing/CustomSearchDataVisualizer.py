from wordcloud import WordCloud, STOPWORDS, ImageColorGenerator
import json
import matplotlib.pyplot as plt
import s3

class CustomSearchDataVisualizer:

    def __init__(self, file_storage, s3_api):
        self._file_storage = file_storage
        self._s3_api = s3_api

    def visualize_raw_search_data(self, input_file_path, output_file_path):
        with open(input_file_path, 'r') as f:
            data = json.load(f)
            text_data = " ".join([item['text'] for item in data])
            print(len(text_data))
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
        file = f'{self._file_storage.get_raw_visualizations_base_path()}/{file_path}'
        print('Processing and storing in s3', file)
        svg = open(file, "rb")
        print('Attempting to upload raw visualized search data to s3')
        self._s3_api.upload_svg(svg, file_path, s3.S3_Location.RAW_DATA_VISUALIZATIONS)
        print('Successfully uploaded')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()
    search_data_visualizer = CustomSearchDataVisualizer(FileStorage(), s3.S3_API())

    print('Visualizing covid search results using a wordcloud')
    search_data_visualizer.visualize_raw_search_data(
        input_file_path='raw_data/search_results/covid-search-results.json',
        output_file_path='raw_data_visualizations/search_results/covid-search-results.svg')

    print('Visualizing h1n1 search results using a wordcloud')
    search_data_visualizer.visualize_raw_search_data(
        input_file_path='raw_data/search_results/h1n1-search-results.json',
        output_file_path='raw_data_visualizations/search_results/h1n1-search-results.svg')

    print('Storing visualized covid search results in S3')
    search_data_visualizer.store_visualized_data('search_results/covid-search-results.svg')

    print('Storing visualized h1n1 search results in S3')
    search_data_visualizer.store_visualized_data('search_results/h1n1-search-results.svg')