from FileStorage import FileStorage
from household_surveys.HouseholdSurveys import HouseholdSurveysApi
from household_surveys.HouseholdSurveysProcessor import HouseholdSurveysProcessor

class DataSourcingFactory:
    def __init__(self):
        self._file_storage = FileStorage()

    def process(self, user_input):
        if user_input == '1':
            print('Retrieving raw covid data for the United States.')
            print('Fix later')
        elif user_input == '2':
            print('Retrieving raw household food security survey data for the United States.')
            household_survey_api = HouseholdSurveysApi(self._file_storage)
            household_survey_api.retrieve_survey_data()
        elif user_input == '3':
            print('Processing raw household food security survey data for the United States.')
            household_survey_processor = HouseholdSurveysProcessor(self._file_storage)
            household_survey_processor.process_survey_data()
        elif user_input == 'q':
            print('Quitting the program...')
            return -1
        else:
            print('Invalid input. Please enter a number from the data or q to quit the program.\n')