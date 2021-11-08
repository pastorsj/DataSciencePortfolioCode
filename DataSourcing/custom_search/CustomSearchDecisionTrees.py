import pandas as pd
import S3Api
from sklearn.feature_extraction.text import CountVectorizer, ENGLISH_STOP_WORDS
from sklearn.model_selection import train_test_split
from sklearn.tree import DecisionTreeClassifier
from sklearn import tree
from nltk.stem import WordNetLemmatizer
import nltk
from sklearn.metrics import ConfusionMatrixDisplay
import matplotlib.pyplot as plt
from subprocess import call
import glob

words = set(nltk.corpus.words.words())
lemmatizer = WordNetLemmatizer()


class CustomSearchDecisionTrees:

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the CustomSearchDecisionTrees class

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

        self.__decision_tree_data_location = 'decision_tree_data/search_results/'
        self.__decision_tree_data_visualizations_location = 'decision_tree_data_visualizations/search_results/'
        self._file_storage.create_directory_if_not_exists(self.__decision_tree_data_location)
        self._file_storage.create_directory_if_not_exists(self.__decision_tree_data_visualizations_location)
        self._additional_stop_words = ['title', 'journal', 'volume', 'author', 'scholar', 'article', 'issue', 'food',
                                       'hunger', 'people', 'million', 'world', 'security', 'insecurity', 'covid',
                                       'locust',
                                       'drought', 'ebola']
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

    def run_decision_tree_analysis(self):
        processed_df = pd.read_csv(self.__processed_data_location, index_col=False)
        processed_pdf_df = pd.read_csv(self.__processed_pdf_data_location, index_col=False)
        df = pd.concat([processed_df, processed_pdf_df], ignore_index=True)
        df['text'] = df['text'].apply(self.filter_non_english_words)

        labels = list(set(df['topic']))
        print('Labels', labels)

        vectorizer = CountVectorizer()
        v = vectorizer.fit_transform(df['text'])
        vocab = vectorizer.get_feature_names_out()
        values = v.toarray()
        v_df = pd.DataFrame(values, columns=vocab)
        v_df.insert(loc=0, column='LABEL', value=df['topic'])
        print('Resulting dataframe', v_df)

        file_path = f'{self.__decision_tree_data_location}labeled_dataframe.csv'
        v_df.to_csv(file_path, index=False)
        print('Wrote labeled dataframe to csv')

        train_df, test_df = train_test_split(v_df, test_size=0.3)
        train_df.to_csv(f'{self.__decision_tree_data_location}training_set.csv', index=False)
        train_df.to_csv(f'{self.__decision_tree_data_location}testing_set.csv', index=False)
        print('Split data into training and testing sets')

        print('Trying decision trees using best splitter')
        self.__run_decision_tree(train_df, test_df, labels, 'entropy', 'best', 4, 'entropy-4-best')
        self.__run_decision_tree(train_df, test_df, labels, 'gini', 'best', 4, 'gini-4-best')
        self.__run_decision_tree(train_df, test_df, labels, 'entropy', 'best', 5, 'entropy-5-best')
        self.__run_decision_tree(train_df, test_df, labels, 'gini', 'best', 5, 'gini-5-best')
        self.__run_decision_tree(train_df, test_df, labels, 'entropy', 'best', 3, 'entropy-3-best')
        self.__run_decision_tree(train_df, test_df, labels, 'gini', 'best', 3, 'gini-3-best')
        self.__run_decision_tree(train_df, test_df, labels, 'entropy', 'best', 100, 'entropy-overfit-best')
        self.__run_decision_tree(train_df, test_df, labels, 'gini', 'best', 100, 'gini-overfit-best')

    def __run_decision_tree(self, train_df, test_df, labels, criterion, splitter, depth, file_description):
        # Split labels from df
        train_labels = train_df['LABEL']
        train_df = train_df.drop(['LABEL'], axis=1)

        test_labels = test_df['LABEL']
        test_df = test_df.drop(['LABEL'], axis=1)

        dt = DecisionTreeClassifier(criterion=criterion,
                                    splitter=splitter,
                                    random_state=123,
                                    max_depth=depth)

        dt.fit(train_df, train_labels)
        features = train_df.columns
        print('Fit training data using decision tree')

        tree.export_graphviz(dt,
                             out_file=f'{self.__decision_tree_data_visualizations_location}decision_tree_{file_description}.dot',
                             feature_names=features,
                             class_names=labels,
                             filled=True,
                             rounded=True,
                             proportion=False,
                             precision=2)

        call(['dot', '-Tpng', f'{self.__decision_tree_data_visualizations_location}decision_tree_{file_description}.dot', '-o', f'{self.__decision_tree_data_visualizations_location}decision_tree_{file_description}.png', '-Gdpi=600'])
        print('Saved decision tree to image using graphviz')

        dt_pred = dt.predict(test_df)
        df_confusion = pd.crosstab(test_labels, dt_pred, rownames=['Actual'], colnames=['Predicted'], margins=True)
        df_confusion.to_csv(f'{self.__decision_tree_data_location}confusion_matrix_{file_description}.csv')
        print('Made predictions based on the text. Below is the confusion matrix.')
        print(df_confusion)

        ConfusionMatrixDisplay.from_predictions(test_labels, dt_pred)
        plt.savefig(f'{self.__decision_tree_data_visualizations_location}confusion_matrix_visual_{file_description}.png')

        importance = dt.feature_importances_

        fig2 = plt.figure(figsize=(15, 10))
        ax = pd.Series(importance, index=features).nlargest(10).plot(kind='barh', title="Feature Importance")
        ax.set(xlabel="Importance Level", ylabel="Feature")
        fig2.savefig(f'{self.__decision_tree_data_visualizations_location}feature_importance_{file_description}.png')

    def store_in_s3(self):
        png_visualizations = list(glob.iglob(f'{self.__decision_tree_data_visualizations_location}/**/*.png', recursive=True))
        for file in png_visualizations:
            print('Opening file', file)
            png = open(file, "rb")
            print('Attempting to upload decision tree visualized search data to s3')
            self._s3_api.upload_png(png, file.replace('decision_tree_data_visualizations/', ''), S3Api.S3Location.DECISION_TREE_DATA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            png.close()

        clustered_csv_data = list(glob.iglob(f'{self.__decision_tree_data_location}/**/*.csv', recursive=True))
        for file in clustered_csv_data:
            print('Opening file', file)
            df = pd.read_csv(file)
            print('Attempting to upload decision tree search data to s3')
            self._s3_api.upload_df(df, file.replace('decision_tree_data/', ''), S3Api.S3Location.DECISION_TREE_DATA)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')

        print('Uploaded all files')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage

    load_dotenv()
    fs = FileStorage()

    search_decision_trees = CustomSearchDecisionTrees(fs, S3Api.S3Api())
    search_decision_trees.run_decision_tree_analysis()
    search_decision_trees.store_in_s3()
