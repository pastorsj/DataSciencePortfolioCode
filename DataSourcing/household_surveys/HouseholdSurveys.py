from bs4 import BeautifulSoup
import requests
import re
import S3Api
from datetime import datetime
import json
import glob

# Constants
STORE_DATA = True


class HouseholdSurveysApi:
    """
    Retrieves weekly household surveys from the census. These surveys are weekly and concern the effects of
    Covid on American households.
    """

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the HouseholdSurveysApi class

        Parameters
        ----------
        :param file_storage: FileStorage, Required
            The file storage class used to store raw/processed data
        :param s3_api: S3_API, Required
            The S3 api wrapper class used to store data in AWS S3

        ----------
        """
        self._household_surveys_endpoint = 'https://www2.census.gov/programs-surveys/demo/tables/hhp/'
        self._household_surveys_data_table_endpoint = 'https://www.census.gov/programs-surveys/household-pulse-survey/data.html'
        self._file_storage = file_storage
        self._s3_api = s3_api

    def retrieve_survey_data(self):
        """Retrieves the raw weekly survey data and saves it"""
        response = requests.get(self._household_surveys_endpoint)
        soup = BeautifulSoup(response.text, 'lxml')
        survey_years = self.retrieve_survey_years(soup)
        survey_data = dict()
        for survey_year in survey_years:
            survey_data[survey_year] = self.retrieve_food_surveys(survey_year)

        self.save_survey_data(survey_data)
        print('Saved all surveys')

        self.retrieve_household_survey_dates()
        return survey_data

    def retrieve_survey_years(self, soup):
        """Parses the html using BeautifulSoup to determine the years the survey was issued

        Parameters
        ----------
        :param soup: BeautifulSoup, Required
            The parsed html containing information on survey years

        ----------
        """
        result = soup.find_all('a', attrs={"href": re.compile(r'[0-9]{4}/')})
        return [r.text.replace('/', '') for r in result]

    def retrieve_food_surveys(self, survey_year):
        """Retrieves the food surveys for each year

        Parameters
        ----------
        :param survey_year: Number, Required
            The year the surveys were run

        ----------
        """
        survey_week_data = dict()
        survey_weeks_endpoint = f'{self._household_surveys_endpoint}{survey_year}'
        response = requests.get(survey_weeks_endpoint)
        soup = BeautifulSoup(response.text, 'lxml')
        survey_weeks = self.retrieve_survey_weeks(soup)

        # Retrieve surveys per week given the year
        for survey_week in survey_weeks:
            survey_week_data[survey_week] = self.retrieve_surveys(f'{survey_weeks_endpoint}/{survey_week}')

        return survey_week_data

    def retrieve_survey_weeks(self, soup):
        """Parses the html using BeautifulSoup to determine the weeks the survey was issued

        Parameters
        ----------
        :param soup: BeautifulSoup, Required
            The parsed html containing information on survey weeks

        ----------
        """
        result = soup.find_all('a', attrs={"href": re.compile(r'wk[0-9]{1,2}/')})
        return [r.text.replace('/', '') for r in result]

    def retrieve_surveys(self, survey_week_endpoint):
        """Retrieves the food survey from each endpoint

        Parameters
        ----------
        :param survey_week_endpoint: String, Required
            The endpoint containing a list of surveys

        ----------
        """
        response = requests.get(survey_week_endpoint)
        soup = BeautifulSoup(response.text, 'lxml')
        return self.retrieve_survey_xlsx(soup)

    def retrieve_survey_xlsx(self, soup):
        """Parses the html using BeautifulSoup to retrieve the individual survey files containing information on food

        Parameters
        ----------
        :param soup: BeautifulSoup, Required
            The parsed html containing the actual survey xlsx files

        ----------
        """
        result = soup.find_all('a', attrs={"href": re.compile(r'^food[1-9]')})
        return [r.text for r in result]

    def save_survey_data(self, survey_data):
        """Saves the raw survey data

        Parameters
        ----------
        :param survey_data: Dictionary, Required
            The dictionary containing the file structure for the surveys

        ----------
        """
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

    def retrieve_household_survey_dates(self):
        response = requests.get(self._household_surveys_data_table_endpoint)
        soup = BeautifulSoup(response.text, 'lxml')
        result = soup.find_all('a', attrs={'title': re.compile(r'Week [0-9]{1,2} Household Pulse Survey:')})
        weekly_data = [(r.get('href'), r.get('title')) for r in result]
        week_regex = re.compile(r'Week [0-9]{1,2}')
        year_regex = re.compile(r'\d{4}')

        print(weekly_data)
        map_of_dates = {}
        for entry in weekly_data:
            week = week_regex.match(entry[1]).group(0).replace('Week ', '')
            year = list(filter(lambda x: year_regex.match(x) is not None, entry[0].split('/')))[0]
            date = ' '.join(entry[1].split(' – ')[0].split(' ')[-2:]) + ' ' + year
            actual_date = datetime.strptime(date, '%B %d %Y')
            map_of_dates[week] = actual_date.strftime('%Y-%m-%d')

        print(map_of_dates)
        formatted_contents = json.dumps(map_of_dates, indent=4, sort_keys=True)
        self._file_storage.store_as_file(f'survey_data/survey_metadata.json', formatted_contents)

    def store_survey_data(self):
        print('Store raw survey data in S3')

        processed_files = list(glob.iglob('raw_data/survey_data/**/*.xlsx', recursive=True))
        for file in processed_files:
            print('Opening file', file)
            contents = open(file, 'rb')
            print('Uploading', file, 'to S3')
            self._s3_api.upload_bytes(contents, file.replace('raw_data/', ''), S3Api.S3Location.RAW_DATA)
            contents.close()

        print('Uploaded all files')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()

    household_surveys_instance = HouseholdSurveysApi(FileStorage(), S3Api.S3Api())

    # print('Retrieving raw household survey data')
    # household_surveys_instance.retrieve_survey_data()

    if STORE_DATA:
        print('Storing raw household survey data')
        household_surveys_instance.store_survey_data()
