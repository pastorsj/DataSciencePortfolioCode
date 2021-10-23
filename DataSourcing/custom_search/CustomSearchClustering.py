import pandas as pd
import S3Api
from sklearn.feature_extraction.text import CountVectorizer, TfidfVectorizer, ENGLISH_STOP_WORDS
from sklearn.cluster import KMeans
import matplotlib.pyplot as plt
from sklearn import metrics
from sklearn.decomposition import PCA
import numpy as np
import plotly.express as px
from sklearn import preprocessing
from sklearn.cluster import AgglomerativeClustering
import plotly.figure_factory as ff
from sklearn.cluster import DBSCAN
import os
import glob
import codecs

STORE_DATA = False


class CustomSearchClustering:

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the CustomSearchData class

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
        self.__clustered_visualizations_location = 'clustered_data_visualizations/search_results'
        self.__clustered_data_location = 'clustered_data/search_results'
        self._additional_stop_words = ['title', 'journal', 'volume', 'author', 'scholar', 'article', 'issue']
        self._other_k_values = [3, 4, 6, 8, 10]

    def cluster_search_data(self):
        self.__clean_clustered_visualizations()
        processed_df = pd.read_csv(self.__processed_data_location)
        print(processed_df.head())

        stop_words = ENGLISH_STOP_WORDS.union(self._additional_stop_words)
        print('----------------------------------')
        print('Trying count vectorizer...')
        print('----------------------------------')
        vectorizer = CountVectorizer(stop_words=stop_words)
        self.__cluster_using_vectorizer(processed_df, vectorizer, 'count')

        print('----------------------------------')
        print('Trying td vectorizer...')
        print('----------------------------------')
        vectorizer = TfidfVectorizer(stop_words=stop_words)
        self.__cluster_using_vectorizer(processed_df, vectorizer, 'tfidf')

    def __clean_clustered_visualizations(self):
        all_files = list(glob.iglob(f'{self.__clustered_visualizations_location}/**/*.html', recursive=True)) + \
                    list(glob.iglob(f'{self.__clustered_visualizations_location}/**/*.png', recursive=True))
        print('Remove all files in the directory', all_files)
        for f in all_files:
            os.remove(f)

    def __cluster_using_vectorizer(self, df, vectorizer, vectorizer_type):
        normalized_label = f'normalized_{vectorizer_type}'
        not_normalized_label = f'not_{normalized_label}'
        v = vectorizer.fit_transform(df['text'])
        vocab = vectorizer.get_feature_names()
        values = v.toarray()
        v_df = pd.DataFrame(values, columns=vocab)
        print('----------------------------------')
        print('Non normalized data')
        print('----------------------------------')
        df_not_normalized = pd.DataFrame(v_df)
        self.__cluster(df_not_normalized, df, not_normalized_label, 'Not Normalized', vectorizer_type)
        pca_analysis_results_nn = self.__run_pca_analysis(df_not_normalized, df)
        df['PC0_NN'] = pca_analysis_results_nn['PC0']
        df['PC1_NN'] = pca_analysis_results_nn['PC1']
        df['PC2_NN'] = pca_analysis_results_nn['PC2']


        print('----------------------------------')
        print('Normalized data')
        print('----------------------------------')
        df_normalized = pd.DataFrame(preprocessing.normalize(v_df))
        self.__cluster(df_normalized, df, normalized_label, 'Normalized', vectorizer_type)
        pca_analysis_results_n = self.__run_pca_analysis(df_normalized, df)
        self.__run_density_clustering(df_normalized, df, normalized_label)
        df['PC0_N'] = pca_analysis_results_n['PC0']
        df['PC1_N'] = pca_analysis_results_n['PC1']
        df['PC2_N'] = pca_analysis_results_n['PC2']

        print('Plotting clusters using k-means, hierarchical, and density scan')
        self.__plot_clusters(df, f'{normalized_label}_calculated_k_means', 'PC0_N', 'PC1_N', 'PC2_N', f'Plot of normalized clusters using K-Means ({vectorizer_type})')
        self.__plot_clusters(df, f'{normalized_label}_3_k_means', 'PC0_N', 'PC1_N', 'PC2_N', f'Plot of normalized clusters using K-Means (k=3) ({vectorizer_type})')
        self.__plot_clusters(df, f'{normalized_label}_4_k_means', 'PC0_N', 'PC1_N', 'PC2_N', f'Plot of normalized clusters using K-Means (k=4) ({vectorizer_type})')
        self.__plot_clusters(df, f'{normalized_label}_6_k_means', 'PC0_N', 'PC1_N', 'PC2_N', f'Plot of normalized clusters using K-Means (k=6) ({vectorizer_type})')
        self.__plot_clusters(df, f'{normalized_label}_8_k_means', 'PC0_N', 'PC1_N', 'PC2_N', f'Plot of normalized clusters using K-Means (k=8) ({vectorizer_type})')
        self.__plot_clusters(df, f'{normalized_label}_10_k_means', 'PC0_N', 'PC1_N', 'PC2_N', f'Plot of normalized clusters using K-Means (k=10) ({vectorizer_type})')
        self.__plot_clusters(df, f'{not_normalized_label}_calculated_k_means', 'PC0_NN', 'PC1_NN', 'PC2_NN', f'Plot of non normalized clusters using K-Means ({vectorizer_type})')
        self.__plot_clusters(df, f'{normalized_label}_3_hierarchical', 'PC0_N', 'PC1_N', 'PC2_N', f'Plot of normalized clusters using Hiearchical Clustering ({vectorizer_type}) (k=3)')
        self.__plot_clusters(df, f'{normalized_label}_4_hierarchical', 'PC0_N', 'PC1_N', 'PC2_N', f'Plot of normalized clusters using Hiearchical Clustering ({vectorizer_type}) (k=4)')
        self.__plot_clusters(df, f'{normalized_label}_6_hierarchical', 'PC0_N', 'PC1_N', 'PC2_N', f'Plot of normalized clusters using Hiearchical Clustering ({vectorizer_type}) (k=6)')
        self.__plot_clusters(df, f'{normalized_label}_8_hierarchical', 'PC0_N', 'PC1_N', 'PC2_N', f'Plot of normalized clusters using Hiearchical Clustering ({vectorizer_type}) (k=8)')
        self.__plot_clusters(df, f'{normalized_label}_10_hierarchical', 'PC0_N', 'PC1_N', 'PC2_N', f'Plot of normalized clusters using Hiearchical Clustering ({vectorizer_type}) (k=10)')
        self.__plot_clusters(df, f'{normalized_label}_density', 'PC0_N', 'PC1_N', 'PC2_N', f'Plot of normalized clusters using Density Scan ({vectorizer_type})')

        df = df.drop(columns=['text'])
        df.to_csv(f'{self.__clustered_data_location}/clustered_search_data.csv', index=False)

    def __cluster(self, df, input_df, clustering_type, graph_prefix, vectorizer_type):
        list_of_inertias = []
        list_of_silhouette_scores = []
        k_range = list(range(2, 10))
        for k in k_range:
            k_means = KMeans(k, max_iter=1000)
            k_means.fit_predict(df)

            list_of_inertias.append(k_means.inertia_)
            score = metrics.silhouette_score(df, k_means.labels_, metric='correlation')
            list_of_silhouette_scores.append(score)

        self.plot_elbow_method(k_range, list_of_inertias, graph_prefix, vectorizer_type, clustering_type)
        self.plot_silhouette_method(k_range, list_of_silhouette_scores, graph_prefix, vectorizer_type, clustering_type)

        k_range_np = np.array(k_range)
        sil_scores = np.array(list_of_silhouette_scores)

        # Find the max k-value from the silhouette scores
        k_value = k_range_np[sil_scores == np.max(sil_scores)][0]
        print('Max k-value', k_value)

        k_means = KMeans(k_value).fit(df)
        k_means_label = f'{clustering_type}_calculated_k_means_label'
        input_df[k_means_label] = k_means.labels_

        self.__plot_silhouette_clusters(df, k_means, k_value, vectorizer_type, clustering_type)

        print('Analysing 5 other random k values for comparison purposes', self._other_k_values)
        for random_k_value in self._other_k_values:
            k_means_r = KMeans(random_k_value).fit(df)
            k_means_label_r = f'{clustering_type}_{random_k_value}_k_means_label'
            input_df[k_means_label_r] = k_means_r.labels_
            self.__plot_silhouette_clusters(df, k_means_r, random_k_value, vectorizer_type, clustering_type)

        self.__run_hierarchical_clustering(df, 3, input_df, clustering_type)
        self.__run_hierarchical_clustering(df, 4, input_df, clustering_type)
        self.__run_hierarchical_clustering(df, 6, input_df, clustering_type)
        self.__run_hierarchical_clustering(df, 8, input_df, clustering_type)
        self.__run_hierarchical_clustering(df, 10, input_df, clustering_type)
        self.__plot_dendrogram(df, input_df, clustering_type, vectorizer_type)

    def plot_elbow_method(self, k_range, list_of_inertias, graph_prefix, vectorizer_type, clustering_type):
        print('Plotting elbow method')
        plt.figure()
        plt.plot(k_range, list_of_inertias, 'bx-')
        plt.xlabel('k')
        plt.ylabel('Inertia')
        plt.title(f'Plot of elbow method using Inertia -- {graph_prefix} ({vectorizer_type})')
        plt.savefig(f'{self.__clustered_visualizations_location}/elbow_method/elbow_method_{clustering_type}.png')

        df = pd.DataFrame(data={'K': k_range, 'Inertia': list_of_inertias})
        df.to_csv(f'{self.__clustered_data_location}/elbow_method/elbow_method_{clustering_type}.csv', index=False)

    def plot_silhouette_method(self, k_range, list_of_silhouette_scores, graph_prefix, vectorizer_type, clustering_type):
        print('Plotting silhouette method')
        plt.figure()
        plt.plot(k_range, list_of_silhouette_scores, 'bx-')
        plt.xlabel('k')
        plt.ylabel('Silhouette Score')
        plt.title(f'Plot of silhouette method -- {graph_prefix} ({vectorizer_type})')
        plt.savefig(f'{self.__clustered_visualizations_location}/silhouette_method/silhouette_method_{clustering_type}.png')

        df = pd.DataFrame(data={'K': k_range, 'Silhouette Score': list_of_silhouette_scores})
        df.to_csv(f'{self.__clustered_data_location}/silhouette_method/silhouette_method_{clustering_type}.csv', index=False)

    def __run_pca_analysis(self, df_normalized, input_df):
        print('Running PCA Analysis to reduce dimensionality')
        text_pca = PCA(n_components=3)
        df_normalized = np.transpose(df_normalized)
        text_pca.fit(df_normalized)
        components = pd.DataFrame(text_pca.components_.T, columns=['PC%s' % _ for _ in range(3)])
        components['topic'] = input_df['topic']
        return components

    def clusterByTopic(self, cluster, topic):
        return cluster.value_counts()[topic] if topic in cluster.value_counts() else 0

    def __plot_clusters(self, df, clustering_type, x, y, z, title):
        k_means_label = f'{clustering_type}_label'
        fig = px.scatter(df, x=x, y=y, text="topic", color=k_means_label, hover_data=['topic', 'link'], log_x=True,
                         size_max=60)
        fig.update_traces(textposition='top center')

        fig.update_layout(
            height=800,
            title_text=title
        )
        output_file = f'{self.__clustered_visualizations_location}/clustered_2d/{clustering_type}.html'
        fig.write_html(output_file)

        fig3d = px.scatter_3d(df, x=x, y=y, z=z, text="topic", color=k_means_label, hover_data=['topic', 'link'],)
        fig3d.update_traces(textposition='top center')

        fig3d.update_layout(
            height=800,
            title_text=title
        )

        output_file = f'{self.__clustered_visualizations_location}/clustered_3d/{clustering_type}.html'
        fig3d.write_html(output_file)

        print('Gathering Statistics')
        statistics_df = df[['topic', k_means_label]].groupby([k_means_label]).agg(
            covid=pd.NamedAgg(column='topic', aggfunc=lambda t: self.clusterByTopic(t, 'covid')),
            drought=pd.NamedAgg(column='topic', aggfunc=lambda t: self.clusterByTopic(t, 'drought')),
            locusts=pd.NamedAgg(column='topic', aggfunc=lambda t: self.clusterByTopic(t, 'locusts')),
            ebola=pd.NamedAgg(column='topic', aggfunc=lambda t: self.clusterByTopic(t, 'ebola'))
        )
        statistics_df['Cluster'] = [i for i in range(statistics_df.shape[0])]
        output_file = f'{self.__clustered_data_location}/clustering_statistics/{clustering_type}.csv'
        statistics_df.to_csv(output_file, index=False)
        print(statistics_df)


    def __plot_silhouette_clusters(self, df, k_means, k_value, vectorizer_type, clustering_type):
        print('Plotting silhouette clusters', k_value)
        plt.figure()
        # get silhouette scores
        sil_coe = metrics.silhouette_samples(df, k_means.labels_)
        sil_score = metrics.silhouette_score(df, k_means.labels_)

        # create subplots and define range
        low_range = 0
        up_range = 0

        # plot bar plot for each cluster
        for cluster in set(k_means.labels_):
            cluster_coefs = sil_coe[k_means.labels_ == cluster]
            cluster_coefs.sort()
            up_range += len(cluster_coefs)
            plt.barh(range(low_range, up_range), cluster_coefs, height=1)
            plt.text(-0.05, (up_range + low_range) / 2, str(cluster))
            low_range += len(cluster_coefs)

        plt.suptitle("Silhouette Coefficients for k = " + str(k_value) + " -- Vectorizer Type = " + vectorizer_type + "\n Score = " + str(round(sil_score, 2)), y=1)
        plt.title("Coefficient Plots")
        plt.xlabel("Silhouette Coefficients")
        plt.ylabel("Cluster")
        plt.yticks([])
        plt.axvline(sil_score, color="red", linestyle="--")
        plt.savefig(f'{self.__clustered_visualizations_location}/silhouette/silhouette_cluster_{k_value}_{clustering_type}.png')

    def __run_hierarchical_clustering(self, df, k_value, input_df, clustering_type):
        print('Running hierarchical clustering with k =', k_value)
        clustered_data = AgglomerativeClustering(n_clusters=k_value, affinity='euclidean', linkage='ward')
        fitted_data = clustered_data.fit(df)
        input_df[f'{clustering_type}_{k_value}_hierarchical_label'] = fitted_data.labels_

    def __plot_dendrogram(self, df, input_df, clustering_type, vectorizer_type):
        print('Plotting dendrogram')
        fig = ff.create_dendrogram(df, labels=input_df['topic'].to_list())
        fig.update_layout(width=800, height=500, title=f'Hierarchical Clustering Dendrogram with '
                                                       f'Vectorizer Type = {vectorizer_type}')
        output_file = f'{self.__clustered_visualizations_location}/dendrogram/dendrogram_{clustering_type}.html'
        fig.write_html(output_file)

    def __run_density_clustering(self, df, input_df, clustering_type):
        print('Running density clustering')
        max_clusters = 0
        associated_labels = []
        for i in map(lambda x: x / 10.0, range(2, 20, 2)):
            for j in range(5, 40):
                set_of_labels = DBSCAN(eps=i, min_samples=j, metric='cosine').fit(df).labels_
                if len(set(set_of_labels)) >= max_clusters:
                    max_clusters = len(set(set_of_labels))
                    associated_labels = set_of_labels

        input_df[f'{clustering_type}_density_label'] = associated_labels
        print('Number of clusters for density', len(set(associated_labels)))

    def store_clustered_search_data(self):
        print('Store processed survey data in S3')

        html_visualizations = list(glob.iglob(f'{self.__clustered_visualizations_location}/**/*.html', recursive=True))
        for file in html_visualizations:
            print('Opening file', file)
            contents = codecs.open(file, 'r')
            print('Uploading', file, 'to S3')
            self._s3_api.upload_html(contents.read(), file.replace('clustered_data_visualizations/', ''), S3Api.S3Location.CLUSTERED_DATA_VISUALIZATIONS)
            contents.close()

        png_visualizations = list(glob.iglob(f'{self.__clustered_visualizations_location}/**/*.png', recursive=True))
        for file in png_visualizations:
            print('Opening file', file)
            png = open(file, "rb")
            print('Attempting to upload clustered visualized search data to s3')
            self._s3_api.upload_png(png, file.replace('clustered_data_visualizations/', ''), S3Api.S3Location.CLUSTERED_DATA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            png.close()

        clustered_csv_data = list(glob.iglob(f'{self.__clustered_data_location}/**/*.csv', recursive=True))
        for file in clustered_csv_data:
            print('Opening file', file)
            df = pd.read_csv(file)
            print('Attempting to upload clustered search data to s3')
            self._s3_api.upload_df(df, file.replace('clustered_data/', ''), S3Api.S3Location.CLUSTERED_DATA)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')

        print('Uploaded all files')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()
    fs = FileStorage()
    fs.create_directory_if_not_exists('clustered_data_visualizations/search_results/elbow_method/')
    fs.create_directory_if_not_exists('clustered_data_visualizations/search_results/silhouette_method/')
    fs.create_directory_if_not_exists('clustered_data_visualizations/search_results/clustered_2d/')
    fs.create_directory_if_not_exists('clustered_data_visualizations/search_results/clustered_3d/')
    fs.create_directory_if_not_exists('clustered_data_visualizations/search_results/silhouette/')
    fs.create_directory_if_not_exists('clustered_data_visualizations/search_results/dendrogram/')
    fs.create_directory_if_not_exists('clustered_data/search_results/clustering_statistics/')
    fs.create_directory_if_not_exists('clustered_data/search_results/elbow_method/')
    fs.create_directory_if_not_exists('clustered_data/search_results/silhouette_method/')

    search_clustering = CustomSearchClustering(fs, S3Api.S3Api())
    search_clustering.cluster_search_data()

    if STORE_DATA:
        search_clustering.store_clustered_search_data()