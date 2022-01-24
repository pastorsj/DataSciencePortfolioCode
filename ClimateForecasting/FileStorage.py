import os


class FileStorage:
    """
    The File Storage is used to store raw data, raw data visualizations, processed data, and
    processed data visualizations in the local file system.

    File Storage Structure

    raw_data/
    raw_data_visualizations/
    processed_data/
    processed_data_visualizations/
    """

    def __init__(self):
        """ Create a new instance of the FileStorage class"""
        self._raw_base_path = 'raw_data'
        self._raw_visualizations_base_path = 'raw_data_visualizations'

    def get_raw_base_path(self):
        """Gets the raw base path"""
        return self._raw_base_path

    def get_raw_visualizations_base_path(self):
        """Gets the raw visualizations base path"""
        return self._raw_visualizations_base_path

    def store_as_file(self, file_name, contents):
        """Stores a file in the raw data directory

        Parameters
        ----------
        :param file_name: String, Required
            The name of the file
        :param contents: String, Required
            The contents of the file

        ----------
        """
        file_path = f'{self._raw_base_path}/{file_name}'
        self.create_directory_if_not_exists(file_path)
        file = open(file_path, 'w')
        file.write(contents)
        file.close()

    def store_df_as_file(self, file_name, df):
        """Stores a dataframe as file in the raw data directory

        Parameters
        ----------
        :param file_name: String, Required
            The name of the file
        :param df: pd.DataFrame, Required
            The dataframe

        ----------
        """
        file_path = f'{self._raw_base_path}/{file_name}'
        self.create_directory_if_not_exists(file_path)
        df.to_csv(file_path, index=False)

    def store_as_file_in_bytes(self, file_name, contents):
        """
        Stores a file in the raw data directory as bytes.
        The use case is for anything that is not a string (like raw excel files)

        Parameters
        ----------
        :param file_name: String, Required
            The name of the file
        :param contents: bytes, Required
            The contents of the file

        ----------
        """
        file_path = f'{self._raw_base_path}/{file_name}'
        self.create_directory_if_not_exists(file_path)
        file = open(file_path, 'wb')
        file.write(contents)
        file.close()

    def create_directory_if_not_exists(self, file_path):
        """Creates a directory if it does not exist already

        Parameters
        ----------
        :param file_path: String, Required
            The file path to be created

        ----------
        """
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
