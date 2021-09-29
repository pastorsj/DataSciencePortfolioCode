from zipfile import ZipFile
from urllib.request import urlopen
from io import BytesIO
import pandas as pd


class WDIIndicators:
    """Retrieve WDI Indicators from the World Bank"""

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the WDIIndicators class

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
        self._base_url = 'https://databank.worldbank.org/data/download/WDI_csv.zip'
        self._wdi_data = 'WDIData.csv'

    def retrieve_wdi_indicator_data(self):
        """Retrieves the raw wdi indicator data"""
        print('Getting zip file from url', self._base_url)
        with urlopen(self._base_url) as zip_response:
            with ZipFile(BytesIO(zip_response.read()), 'r') as zip:
                try:
                    df = pd.read_csv(zip.open(self._wdi_data))
                    print(df.head())
                    output_file_name = '../raw_data/wdi_data/wdi_data.csv'
                    self._file_storage.create_directory_if_not_exists(output_file_name)
                    df.to_csv(output_file_name)
                except Exception as error:
                    print('An error occurred reading', self._wdi_data, error)