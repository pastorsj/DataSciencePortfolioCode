import pandas as pd
import S3Api
from sklearn.feature_extraction.text import CountVectorizer, ENGLISH_STOP_WORDS, TfidfVectorizer
from sklearn.model_selection import train_test_split
from sklearn.naive_bayes import MultinomialNB
from sklearn.svm import LinearSVC, SVC
from nltk.stem import WordNetLemmatizer
import nltk
from sklearn.metrics import ConfusionMatrixDisplay
import matplotlib.pyplot as plt
import glob
from wordcloud import WordCloud, STOPWORDS
import numpy as np

words = set(nltk.corpus.words.words())
lemmatizer = WordNetLemmatizer()


class CustomSearchNB_SVM:

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the CustomSearchNB_SVM class

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
        self.__processed_pdf_data_location = '/Users/sampastoriza/Documents/Programming/DataScienceDevelopment/DataSciencePortfolioCode/PandemicComparison/processed_data/corpus_data/cleaned_corpus_data.csv'

        self.__naive_bayes_data_location = 'naive_bayes_data/search_results/'
        self.__naive_bayes_data_visualizations_location = 'naive_bayes_data_visualizations/search_results/'
        self.__svm_data_location = 'svm_data/search_results/'
        self.__svm_data_visualizations_location = 'svm_data_visualizations/search_results/'
        self._file_storage.create_directory_if_not_exists(self.__naive_bayes_data_location)
        self._file_storage.create_directory_if_not_exists(self.__naive_bayes_data_visualizations_location)
        self._file_storage.create_directory_if_not_exists(self.__svm_data_location)
        self._file_storage.create_directory_if_not_exists(self.__svm_data_visualizations_location)
        self._additional_stop_words = ['title', 'journal', 'volume', 'author', 'scholar', 'article', 'issue', 'food',
                                       'hunger', 'people', 'million', 'world', 'security', 'insecurity', 'covid',
                                       'locust', 'drought', 'ebola']
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

        filtered_vocabulary = [lemmatizer.lemmatize(w.lower()) for w in nltk.wordpunct_tokenize(corpus) if
                               w.lower() in words]
        filtered_vocabulary = [w for w in filtered_vocabulary if len(w) > 2 and w not in self._defined_stop_words]
        return " ".join(filtered_vocabulary)

    def run_analysis(self):
        processed_df = pd.read_csv(self.__processed_data_location, index_col=False)
        processed_pdf_df = pd.read_csv(self.__processed_pdf_data_location, index_col=False)
        df = pd.concat([processed_df, processed_pdf_df], ignore_index=True)
        df['text'] = df['text'].apply(self.filter_non_english_words)
        self.visualize_processed_search_data(df)

        labels = list(set(df['topic']))
        print('Labels', labels)

        vectorizer = CountVectorizer()
        v = vectorizer.fit_transform(df['text'])
        vocab = vectorizer.get_feature_names_out()
        values = v.toarray()
        v_df = pd.DataFrame(values, columns=vocab)
        v_df.insert(loc=0, column='LABEL', value=df['topic'])
        print('Resulting dataframe', v_df)

        file_path = f'{self.__naive_bayes_data_location}labeled_dataframe_count.csv'
        v_df.to_csv(file_path, index=False)
        print('Wrote labeled dataframe to csv')

        train_df, test_df = train_test_split(v_df, test_size=0.3)
        train_df.to_csv(f'{self.__naive_bayes_data_location}training_set_count.csv', index=False)
        train_df.to_csv(f'{self.__naive_bayes_data_location}testing_set_count.csv', index=False)
        print('Split data into training and testing sets')
        self.__run_naive_bayes_analysis(train_df, test_df, vectorizer)

        vectorizer = TfidfVectorizer()
        v = vectorizer.fit_transform(df['text'])
        vocab = vectorizer.get_feature_names_out()
        values = v.toarray()
        v_df = pd.DataFrame(values, columns=vocab)
        v_df.insert(loc=0, column='LABEL', value=df['topic'])
        print('Resulting dataframe', v_df)

        file_path = f'{self.__svm_data_location}labeled_dataframe_tfidf.csv'
        v_df.to_csv(file_path, index=False)
        print('Wrote labeled dataframe to csv')

        train_df, test_df = train_test_split(v_df, test_size=0.3)
        train_df.to_csv(f'{self.__svm_data_location}training_set_tfidf.csv', index=False)
        train_df.to_csv(f'{self.__svm_data_location}testing_set_tfidf.csv', index=False)
        self.__run_svm_analysis(train_df, test_df)

    def __run_naive_bayes_analysis(self, train_df, test_df, vectorizer):
        print('Running Naive Bayes Analysis')
        train_labels = train_df['LABEL']
        train_df = train_df.drop(['LABEL'], axis=1)

        test_labels = test_df['LABEL']
        test_df = test_df.drop(['LABEL'], axis=1)

        nb_model = MultinomialNB()
        nb_model.fit(train_df, train_labels)
        nb_prediction = nb_model.predict(test_df)

        nb_confusion = pd.crosstab(test_labels, nb_prediction, rownames=['Actual'], colnames=['Predicted'], margins=True)
        nb_confusion.to_csv(f'{self.__naive_bayes_data_location}confusion_matrix_nb.csv')
        print('Made predictions based on the text. Below is the confusion matrix.')
        print(nb_confusion)

        ConfusionMatrixDisplay.from_predictions(test_labels, nb_prediction)
        plt.savefig(f'{self.__naive_bayes_data_visualizations_location}confusion_matrix_visual_nb.png')

        zipped = list(zip(vectorizer.get_feature_names_out(), np.exp(nb_model.feature_log_prob_[0])))
        sorted_zip = sorted(zipped, key=lambda t: t[1], reverse=True)
        x, y = zip(*sorted_zip[:10])
        feature_importance_df = pd.DataFrame({'TopFeatures': x, 'Importance': y})
        feature_importance_df.to_csv(f'{self.__naive_bayes_data_location}feature_importance_nb_{nb_model.classes_[0]}.csv', index=False)
        self.__plot_variable_importance(x, y, nb_model.classes_[0])

        zipped = list(zip(vectorizer.get_feature_names_out(), np.exp(nb_model.feature_log_prob_[1])))
        sorted_zip = sorted(zipped, key=lambda t: t[1], reverse=True)
        x, y = zip(*sorted_zip[:10])
        feature_importance_df = pd.DataFrame({'TopFeatures': x, 'Importance': y})
        feature_importance_df.to_csv(f'{self.__naive_bayes_data_location}feature_importance_nb_{nb_model.classes_[1]}.csv', index=False)
        self.__plot_variable_importance(x, y, nb_model.classes_[1])

        zipped = list(zip(vectorizer.get_feature_names_out(), np.exp(nb_model.feature_log_prob_[2])))
        sorted_zip = sorted(zipped, key=lambda t: t[1], reverse=True)
        x, y = zip(*sorted_zip[:10])
        feature_importance_df = pd.DataFrame({'TopFeatures': x, 'Importance': y})
        feature_importance_df.to_csv(f'{self.__naive_bayes_data_location}feature_importance_nb_{nb_model.classes_[2]}.csv', index=False)
        self.__plot_variable_importance(x, y, nb_model.classes_[2])

        print(nb_model.feature_log_prob_)
        zipped = list(zip(vectorizer.get_feature_names_out(), np.exp(nb_model.feature_log_prob_[3])))
        sorted_zip = sorted(zipped, key=lambda t: t[1], reverse=True)
        x, y = zip(*sorted_zip[:10])
        feature_importance_df = pd.DataFrame({'TopFeatures': x, 'Importance': y})
        feature_importance_df.to_csv(f'{self.__naive_bayes_data_location}feature_importance_nb_{nb_model.classes_[3]}.csv', index=False)
        self.__plot_variable_importance(x, y, nb_model.classes_[3])

        print('Probs', nb_model.feature_log_prob_)
        print('Model', nb_model.classes_)


    def __plot_variable_importance(self, x, y, label):
        plt.figure()
        plt.barh(x, y)
        plt.ylabel('Features')
        plt.xlabel('Importance')
        plt.title('Feature Importance of Naive Bayes Model')
        plt.tight_layout()
        plt.savefig(f'{self.__naive_bayes_data_visualizations_location}feature_importance_nb_{label}.png')

    def __run_svm_analysis(self, train_df, test_df):
        print('Running SVM Analysis')
        train_labels = train_df['LABEL']
        train_df = train_df.drop(['LABEL'], axis=1)

        test_labels = test_df['LABEL']
        test_df = test_df.drop(['LABEL'], axis=1)

        print('Running Linear Kernel')
        svm_model_optimal = SVC(C=10, kernel='linear')
        svm_model_optimal.fit(train_df, train_labels)
        svm_prediction = svm_model_optimal.predict(test_df)

        svm_confusion = pd.crosstab(test_labels, svm_prediction, rownames=['Actual'], colnames=['Predicted'], margins=True)
        svm_confusion.to_csv(f'{self.__svm_data_location}confusion_matrix_linear_svm.csv')
        print('Made predictions based on the text. Below is the confusion matrix.')
        print(svm_confusion)

        ConfusionMatrixDisplay.from_predictions(test_labels, svm_prediction)
        plt.savefig(f'{self.__svm_data_visualizations_location}confusion_matrix_visual_linear_svm.png')

        print('Running Radial Basis Kernel')
        svm_model = SVC(C=10, kernel='rbf', gamma="auto")
        svm_model.fit(train_df, train_labels)
        svm_prediction = svm_model.predict(test_df)

        svm_confusion = pd.crosstab(test_labels, svm_prediction, rownames=['Actual'], colnames=['Predicted'], margins=True)
        svm_confusion.to_csv(f'{self.__svm_data_location}confusion_matrix_rbf_svm.csv')
        print('Made predictions based on the text. Below is the confusion matrix.')
        print(svm_confusion)

        ConfusionMatrixDisplay.from_predictions(test_labels, svm_prediction)
        plt.savefig(f'{self.__svm_data_visualizations_location}confusion_matrix_visual_rbf_svm.png')

        print('Running Polynomial Kernel')
        svm_model = SVC(C=20000, kernel='poly', degree=3)
        svm_model.fit(train_df, train_labels)
        svm_prediction = svm_model.predict(test_df)

        svm_confusion = pd.crosstab(test_labels, svm_prediction, rownames=['Actual'], colnames=['Predicted'], margins=True)
        svm_confusion.to_csv(f'{self.__svm_data_location}confusion_matrix_poly_svm.csv')
        print('Made predictions based on the text. Below is the confusion matrix.')
        print(svm_confusion)

        ConfusionMatrixDisplay.from_predictions(test_labels, svm_prediction)
        plt.savefig(f'{self.__svm_data_visualizations_location}confusion_matrix_visual_poly_svm.png')

        print('Running Sigmoid Kernel')
        svm_model = SVC(C=5, kernel='sigmoid')
        svm_model.fit(train_df, train_labels)
        svm_prediction = svm_model.predict(test_df)

        svm_confusion = pd.crosstab(test_labels, svm_prediction, rownames=['Actual'], colnames=['Predicted'], margins=True)
        svm_confusion.to_csv(f'{self.__svm_data_location}confusion_matrix_sigmoid_svm.csv')
        print('Made predictions based on the text. Below is the confusion matrix.')
        print(svm_confusion)

        ConfusionMatrixDisplay.from_predictions(test_labels, svm_prediction)
        plt.savefig(f'{self.__svm_data_visualizations_location}confusion_matrix_visual_sigmoid_svm.png')


    def visualize_processed_search_data(self, processed_df):
        """ Visualizes the processed search data"""
        print('Visualizing processed and combined search data')
        for group in processed_df.groupby(by=['topic']):
            text_data = " ".join(group[1]['text'].to_list())
            topic = group[0]
            print('Generating wordcloud for topic', topic)
            wordcloud = WordCloud(stopwords=STOPWORDS, background_color="white", collocations=False).generate(text_data)
            print('Saving image to file')
            # Save as an svg for scaling purposes
            wordcloud_svg = wordcloud.to_svg(embed_font=True)
            f = open(f'{self.__naive_bayes_data_visualizations_location}{topic}_wordcloud.svg', "w+")
            f.write(wordcloud_svg)
            f.close()

            vectorizer = CountVectorizer(stop_words="english")
            matrix = vectorizer.fit_transform(group[1]['text'])
            feature_names = vectorizer.get_feature_names_out()
            values = matrix.toarray()
            v_df = pd.DataFrame(values, columns=feature_names)
            sums = matrix.sum(axis=0).tolist()[0]
            sorted_frequencies = sorted(zip(feature_names, sums), key=lambda x: -x[1])
            v_df.to_csv(f'{self.__naive_bayes_data_location}{topic}_vectorized.csv')

    def store_in_s3(self):
        png_visualizations = list(glob.iglob(f'{self.__naive_bayes_data_visualizations_location}/**/*.png', recursive=True))
        for file in png_visualizations:
            print('Opening file', file)
            png = open(file, "rb")
            print('Attempting to upload naive bayes visualized search data to s3')
            self._s3_api.upload_png(png, file.replace('naive_bayes_data_visualizations/', ''), S3Api.S3Location.NAIVE_BAYES_DATA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            png.close()

        svg_visualizations = list(glob.iglob(f'{self.__naive_bayes_data_visualizations_location}/**/*.svg', recursive=True))
        for file in svg_visualizations:
            print('Opening file', file)
            svg = open(file, "rb")
            print('Attempting to upload naive bayes visualized search data to s3')
            self._s3_api.upload_svg(svg, file.replace('naive_bayes_data_visualizations/', ''), S3Api.S3Location.NAIVE_BAYES_DATA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            svg.close()

        csv_data = list(glob.iglob(f'{self.__naive_bayes_data_location}/**/*.csv', recursive=True))
        for file in csv_data:
            print('Opening file', file)
            df = pd.read_csv(file)
            print('Attempting to upload naive bayes search data to s3')
            self._s3_api.upload_df(df, file.replace('naive_bayes_data/', ''), S3Api.S3Location.NAIVE_BAYES_DATA)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')

        png_visualizations = list(glob.iglob(f'{self.__svm_data_visualizations_location}/**/*.png', recursive=True))
        for file in png_visualizations:
            print('Opening file', file)
            png = open(file, "rb")
            print('Attempting to upload svm visualized search data to s3')
            self._s3_api.upload_png(png, file.replace('svm_data_visualizations/', ''), S3Api.S3Location.SVM_DATA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            png.close()

        csv_data = list(glob.iglob(f'{self.__svm_data_location}/**/*.csv', recursive=True))
        for file in csv_data:
            print('Opening file', file)
            df = pd.read_csv(file)
            print('Attempting to upload svm search data to s3')
            self._s3_api.upload_df(df, file.replace('svm_data/', ''), S3Api.S3Location.SVM_DATA)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')

        print('Uploaded all files')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage

    load_dotenv()
    fs = FileStorage()

    search_nb_svm = CustomSearchNB_SVM(fs, S3Api.S3Api())
    search_nb_svm.run_analysis()
    search_nb_svm.store_in_s3()