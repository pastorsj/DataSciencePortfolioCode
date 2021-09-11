from dotenv import load_dotenv
from CovidApi import CovidApi
from FileStorage import FileStorage
from HouseholdSurveys import HouseholdSurveysApi
from HouseholdSurveysProcessor import HouseholdSurveysProcessor

load_dotenv()

if __name__ == '__main__':
    household_survey_api = HouseholdSurveysApi(FileStorage())
    print('Retrieving survey data')
    survey_data = household_survey_api.retrieve_survey_data()

    household_survey_processor = HouseholdSurveysProcessor(FileStorage())
    household_survey_processor.process_survey_data()



