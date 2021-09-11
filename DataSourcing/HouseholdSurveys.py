from bs4 import BeautifulSoup
import requests
import re

class HouseholdSurveysApi:

    def __init__(self, file_storage):
        self._household_surveys_endpoint = 'https://www2.census.gov/programs-surveys/demo/tables/hhp/'
        self._file_storage = file_storage

    def retrieve_survey_data(self):
        response = requests.get(self._household_surveys_endpoint)
        soup = BeautifulSoup(response.text, 'lxml')
        survey_years = self.retrieve_survey_years(soup)
        survey_data = dict()
        for survey_year in survey_years:
            survey_data[survey_year] = self.retrieve_food_surveys(survey_year)

        self.save_survey_data(survey_data)
        print('Saved all surveys')
        return survey_data

    def retrieve_survey_years(self, soup):
        result = soup.find_all('a', attrs={"href": re.compile(r'[0-9]{4}/')})
        return [r.text.replace('/', '') for r in result]

    def retrieve_food_surveys(self, survey_year):
        survey_week_data = dict()
        survey_weeks_endpoint = f'{self._household_surveys_endpoint}{survey_year}'
        response = requests.get(survey_weeks_endpoint)
        soup = BeautifulSoup(response.text, 'lxml')
        survey_weeks = self.retrieve_survey_weeks(soup)

        for survey_week in survey_weeks:
            survey_week_data[survey_week] = self.retrieve_surveys(f'{survey_weeks_endpoint}/{survey_week}')

        return survey_week_data

    def retrieve_survey_weeks(self, soup):
        result = soup.find_all('a', attrs={"href": re.compile(r'wk[0-9]{1,2}/')})
        return [r.text.replace('/', '') for r in result]

    def retrieve_surveys(self, survey_week_endpoint):
        response = requests.get(survey_week_endpoint)
        soup = BeautifulSoup(response.text, 'lxml')
        return self.retrieve_survey_xlsx(soup)

    def retrieve_survey_xlsx(self, soup):
        result = soup.find_all('a', attrs={"href": re.compile(r'^food[1-9]')})
        return [r.text for r in result]

    def save_survey_data(self, survey_data):
        survey_years = dict.keys(survey_data)
        for survey_year in survey_years:
            survey_weeks = dict.keys(survey_data[survey_year])
            for survey_week in survey_weeks:
                surveys = survey_data[survey_year][survey_week]
                for survey in surveys:
                    print('Retrieving survey with name', survey, 'from week', survey_week)
                    survey_endpoint = f'{self._household_surveys_endpoint}/{survey_year}/{survey_week}/{survey}'
                    response = requests.get(survey_endpoint)
                    self._file_storage.store_as_file_in_bytes(f'survey_data/{survey_year}/{survey_week}/{survey}', response.content)

