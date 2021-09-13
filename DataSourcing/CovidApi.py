import requests
import json

class CovidApi:

    def __init__(self, file_storage):
        self._cdc_covid_cases_endpoint = 'https://data.cdc.gov/resource/9mfq-cb36.json'
        self._file_storage = file_storage

    def retrieve_us_covid_case_data(self):
        response = requests.get(self._cdc_covid_cases_endpoint)
        json_data = response.json()
        print('Retrieved covid case data')
        formatted_contents = json.dumps(json_data, indent=4, sort_keys=True)
        self._file_storage.store_as_file('covid_cases.json', formatted_contents)
        print('Stored covid case data')
        return json_data

    def retrieve_global_covid_case_data(self):
        print('Todo: Retrieve global covid data for comparison against FIES data')
