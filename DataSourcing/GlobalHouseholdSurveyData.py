import requests
import json
from urllib.request import urlopen
from zipfile import ZipFile
from io import BytesIO

class GlobalHouseholdSurveys:

    '''
    Retrieve high frequency household survey data for covid 19 from 6 countries
    1. Burkina Faso
    2. Ethiopia
    3. Malawi
    4. Mali
    5. Nigeria
    6. Uganda
    '''
    def __init__(self, file_storage):
        self._survey_ids = [
            'BFA_2020_HFPS_V08_M', # Burkina Faso,
            'ETH_2020_HFPS_V07_M', # Ethiopia
            'MWI_2020_HFPS_V09_M', # Malawi
            'MLI_2020_HFPS_V05_M', # Mali
            'NGA_2020_NLPS_V12_M', # Nigeria
            'UGA_2020_HFPS_V07_M' # Uganda
        ]
        self._base_url = 'http://microdata.worldbank.org/index.php'
        self._file_storage = file_storage

    def retrieve_survey_data(self):
        for survey_id in self._survey_ids:
            print('Survey id', survey_id)
            metadata = self.retrieve_survey_metadata(survey_id)
            country = metadata['dataset']['nation']
            food_security_file_names = self.retrieve_food_security_file_names(country, survey_id)
            print(food_security_file_names)
            self.retrieve_food_security_files(survey_id, food_security_file_names)

    def retrieve_survey_metadata(self, survey_id):
        metadata_endpoint = f'{self._base_url}/api/catalog/{survey_id}'
        response = requests.get(metadata_endpoint)
        metadata = response.json()
        print('metadata', metadata)
        country = metadata['dataset']['nation']

        formatted_contents = json.dumps(metadata, indent=4, sort_keys=True)
        self._file_storage.store_as_file(f'{country}/survey_metadata.json', formatted_contents)
        return metadata

    def retrieve_food_security_file_names(self, country, survey_id):
        metadata_endpoint = f'{self._base_url}/api/catalog/{survey_id}/data_files'
        response = requests.get(metadata_endpoint)
        metadata = response.json()
        datafiles = metadata['datafiles']

        formatted_contents = json.dumps(metadata, indent=4, sort_keys=True)
        self._file_storage.store_as_file(f'{country}/datafile_metadata.json', formatted_contents)

        print('Data files', datafiles)

        files = []
        for file in datafiles:
            if 'food security' in datafiles[file]['description'].lower():
                file_name = datafiles[file]['file_name'].replace('.dta', '.csv')
                files.append(file_name)

        return files

    def retrieve_food_security_files(self, survey_id, food_security_file_names):
        print('Todo')





