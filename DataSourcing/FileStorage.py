import os


class FileStorage:

    def __init__(self):
        self._raw_base_path = 'raw_data'
        self._processed_base_path = 'processed_data'

    def get_raw_base_path(self):
        return self._raw_base_path

    def get_processed_base_path(self):
        return self._processed_base_path

    def store_as_file(self, filename, contents):
        file_path = f'{self._raw_base_path}/{filename}'
        self.create_directory_if_not_exists(file_path)
        file = open(file_path, 'w')
        file.write(contents)
        file.close()

    def store_as_file_in_bytes(self, filename, contents):
        file_path = f'{self._raw_base_path}/{filename}'
        self.create_directory_if_not_exists(file_path)
        file = open(file_path, 'wb')
        file.write(contents)
        file.close()

    def store_as_processed_file(self, filename, contents):
        file_path = f'{self._processed_base_path}/{filename}'
        self.create_directory_if_not_exists(file_path)
        file = open(file_path, 'w')
        file.write(contents)
        file.close()

    def create_directory_if_not_exists(self, file_path):
        os.makedirs(os.path.dirname(file_path), exist_ok=True)


