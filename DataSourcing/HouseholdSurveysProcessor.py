import os
import glob
import re
from openpyxl import load_workbook
import csv

class HouseholdSurveysProcessor:

    def __init__(self, file_storage):
        self._survey_data_folder = 'survey_data'
        self._input_base_path = f'{file_storage.get_raw_base_path()}/{self._survey_data_folder}/'
        self._food_sufficiency_filter = 'food sufficiency'
        self._children_information_filter = 'with children'
        self._file_storage = file_storage

    def process_survey_data(self):
        survey_files = self.retrieve_survey_files()
        print('Survey Files', survey_files)
        for survey_file in survey_files:
            # survey_file = 'raw_data/survey_data/2021/wk36/food5_week36.xlsx'
            wb = load_workbook(survey_file)
            print('Reading the workbook and processing into a csv', survey_file)
            if self._workbook_contains_food_sufficiency(wb) and not self._workbook_contains_prior_to_covid_19(wb):
                print('Contains food sufficiency information', survey_file)

                contains_errors = self._file_contains_standard_errors(survey_file)
                print('Does it contain standard errors?', contains_errors)
                contains_child_info = self.workbook_includes_information_on_children(wb)
                print('Does it include information on children?', contains_child_info)

                self._process_workbook(wb, contains_errors=contains_errors, contains_child_info=contains_child_info)

            wb.close()

    def retrieve_survey_files(self):
        return list(glob.iglob(self._input_base_path + '**/*.xlsx', recursive=True))

    def _workbook_contains_food_sufficiency(self, wb):
        first_cell = wb['US']['A1'].value
        return self._food_sufficiency_filter in str(first_cell).lower()

    def _workbook_contains_prior_to_covid_19(self, wb):
        first_cell = wb['US']['A1'].value
        return 'prior to covid-19' in str(first_cell).lower()

    def _file_contains_standard_errors(self, filepath):
        return '_se_' in filepath

    def workbook_includes_information_on_children(self, wb):
        first_cell = wb['US']['A1'].value
        return self._children_information_filter in str(first_cell).lower()

    def _process_workbook(self, wb, contains_errors, contains_child_info):
        sheet_names = wb.get_sheet_names()
        r = re.compile(r'[A-Z]{2}')
        filtered_sheet_names = list(filter(r.match, sheet_names))
        week_information = wb['US']['A2'].value
        week_regex = re.compile(r'Week [0-9]{1,2}')
        week = week_regex.search(week_information).group(0)

        output = 'State,Total,Enough of the kinds of food wanted,Enough food but not always the kinds wanted,Sometimes not enough to eat,Often not enough to eat,Did not report\n'
        for sheet_name in filtered_sheet_names:
            if sheet_name != 'US':
                sheet = wb[sheet_name]
                output += f'{sheet_name},'
                output += ','.join([str(statistic.value) for statistic in sheet['B8:G8'][0]]) + '\n'

        output_path = '/'.join([
            self._survey_data_folder,
            'errors' if contains_errors else 'standard',
            'children' if contains_child_info else 'all',
            f'{week}.csv'])

        print(output_path)
        self._file_storage.store_as_processed_file(output_path, output)
