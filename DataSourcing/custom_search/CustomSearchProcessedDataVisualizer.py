import pandas as pd
from wordcloud import WordCloud, STOPWORDS
from sklearn.feature_extraction.text import CountVectorizer
import matplotlib.pyplot as plt
import S3Api
import glob

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
            The S3 api wrapper class used to store data in AWS S3

        ----------
        """
        self._file_storage = file_storage
        self._s3_api = s3_api
        self.__processed_data_location = 'processed_data/search_results/cleaned_search_data.csv'
        self.__processed_visualizations_location = 'processed_data_visualizations/search_results'

    def visualize_processed_search_data(self):
        """ Visualizes the processed search data"""
        processed_df = pd.read_csv(self.__processed_data_location)
        for group in processed_df.groupby(by=['topic']):
            text_data = " ".join(group[1]['text'].to_list())
            topic = group[0]
            print('Generating wordcloud for topic', topic)
            wordcloud = WordCloud(stopwords=STOPWORDS, background_color="white").generate(text_data)
            plt.figure()
            plt.imshow(wordcloud, interpolation="bilinear")
            plt.axis("off")
            plt.show()
            print('Saving image to file')
            # Save as an svg for scaling purposes
            wordcloud_svg = wordcloud.to_svg(embed_font=True)
            f = open(f'{self.__processed_visualizations_location}/{topic}_wordcloud.svg', "w+")
            f.write(wordcloud_svg)
            f.close()

            vectorizer = CountVectorizer(stop_words="english")
            matrix = vectorizer.fit_transform(group[1]['text'])
            feature_names = vectorizer.get_feature_names()
            values = matrix.toarray()
            v_df = pd.DataFrame(values, columns=feature_names)
            sums = matrix.sum(axis=0).tolist()[0]
            print(feature_names)
            print(sums)
            sorted_frequencies = sorted(zip(feature_names, sums), key=lambda x: -x[1])
            print(sorted_frequencies[0:10])
            v_df.to_csv(f'processed_data/search_results/{topic}_vectorized.csv')

    def store_visualized_data(self):
        """Stores the processed visualization in S3"""
        svg_visualizations = list(glob.iglob(f'processed_data_visualizations/search_results/*.svg', recursive=True))
        for file in svg_visualizations:
            print('Opening file', file)
            svg = open(file, "rb")
            print('Attempting to upload processed visualized search data to s3')
            self._s3_api.upload_svg(svg, file.replace('processed_data_visualizations/', ''), S3Api.S3Location.PROCESSED_DATA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            svg.close()

        processed_data = list(glob.iglob(f'processed_data/search_results/*.csv', recursive=True))
        for file in processed_data:
            print('Opening file', file)
            df = pd.read_csv(file)
            print('Attempting to upload processed search data to s3')
            self._s3_api.upload_df(df, file.replace('processed_data/', ''), S3Api.S3Location.PROCESSED_DATA)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')


if __name__ == '__main__':
    from FileStorage import FileStorage
    from dotenv import load_dotenv
    load_dotenv()
    FileStorage().create_directory_if_not_exists('processed_data_visualizations/search_results/')

    search_data_visualizer = CustomSearchProcessedDataVisualizer(FileStorage(), S3Api.S3Api())

    print('Visualizing search results using a wordcloud')
    search_data_visualizer.visualize_processed_search_data()

    if STORE_DATA:
        print('Storing visualized search results in S3')
        search_data_visualizer.store_visualized_data()