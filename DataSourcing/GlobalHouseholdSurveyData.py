import requests
import json
from zipfile import ZipFile
import re
import pandas as pd


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
            'BFA_2020_HFPS_V08_M',  # Burkina Faso
            'ETH_2020_HFPS_V07_M',  # Ethiopia
            'MWI_2020_HFPS_V09_M',  # Malawi
            'MLI_2020_HFPS_V05_M',  # Mali
            'NGA_2020_NLPS_V12_M',  # Nigeria
            'UGA_2020_HFPS_V07_M'  # Uganda
        ]
        self._keywords = ['food security', 'food insecurity']
        self._base_url = 'http://microdata.worldbank.org/index.php'
        self._file_storage = file_storage

    def retrieve_survey_data(self):
        for survey_id in self._survey_ids:
            print('Survey id', survey_id)
            metadata = self.retrieve_survey_metadata(survey_id)
            country = metadata['dataset']['nation']
            food_security_file_names = self.retrieve_food_security_file_names(country, survey_id)
            print(food_security_file_names)
            self.retrieve_food_security_files(country, survey_id, food_security_file_names)

    def retrieve_survey_metadata(self, survey_id):
        metadata_endpoint = f'{self._base_url}/api/catalog/{survey_id}'
        response = requests.get(metadata_endpoint)
        metadata = response.json()
        print('metadata', metadata)
        country = metadata['dataset']['nation']

        formatted_contents = json.dumps(metadata, indent=4, sort_keys=True)
        self._file_storage.store_as_file(f'global_survey_data/countries/{country}/survey_metadata.json', formatted_contents)
        return metadata

    def retrieve_food_security_file_names(self, country, survey_id):
        metadata_endpoint = f'{self._base_url}/api/catalog/{survey_id}/data_files'
        response = requests.get(metadata_endpoint)
        metadata = response.json()
        datafiles = metadata['datafiles']

        formatted_contents = json.dumps(metadata, indent=4, sort_keys=True)
        self._file_storage.store_as_file(f'global_survey_data/countries/{country}/datafile_metadata.json', formatted_contents)

        print('Data files', datafiles)

        round_number_re = re.compile(r'Round [1-9]{1,2}')
        files = []
        for file in datafiles:
            if datafiles[file]['description'] != None and any(keyword in datafiles[file]['description'].lower() for keyword in self._keywords):
                round_number = round_number_re.search(datafiles[file]['description']).group(0).replace(' ', '').lower()
                print('Round', round_number)
                file_name = datafiles[file]['file_name'].replace('.dta', '.csv')
                files.append(f'{round_number}/{file_name}'.lower())

        return files

    def retrieve_food_security_files(self, country, survey_id, food_security_file_names):
        zip_filename = f'raw_data/global_survey_data/{survey_id}_CSV.zip'
        round_number_re = re.compile(r'[round|r][0-9]{1,2}')
        with ZipFile(zip_filename, 'r') as zip:
            for file in zip.namelist():
                print(file)
                print(food_security_file_names)

            files_to_extract = [file for file in zip.namelist() if any(file in file_name for file_name in food_security_file_names)]
            print('Files to extract', files_to_extract)
            for file_name in files_to_extract:
                print('Extracting', file_name)
                try:
                    df = pd.read_csv(zip.open(file_name))
                    print(df.head())
                    round_number = round_number_re.search(file_name).group(0).lower()
                    print(round_number)
                    output_file_name = f'raw_data/global_survey_data/countries/{country}/{round_number}_fies.csv'
                    self._file_storage.create_directory_if_not_exists(output_file_name)
                    df.to_csv(output_file_name)
                except Exception as error:
                    print('An error occurred reading', file_name, error)