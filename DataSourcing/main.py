from dotenv import load_dotenv
from DataSourcingFactory import DataSourcingFactory
from GlobalHouseholdSurveyData import GlobalHouseholdSurveys
from FileStorage import FileStorage

load_dotenv()
factory = DataSourcingFactory()

def main():
    print_menu()
    user_input = input('> ')
    print('----------------\n')
    code = factory.process(user_input)
    if code == -1:
        return;
    else:
        print('\n')
        main()


def print_menu():
    print('Menu')
    print('----------------')
    print('[1] Retrieve raw covid case data for the United States.')
    print('[2] Retrieve raw household food security survey data for the United States.')
    print('[3] Process raw household food security survey data for the United States.')
    print('[q] Quit the program.')
    print('----------------')


if __name__ == '__main__':
    # print('Welcome to the data sourcing program. What would you like to do?')
    # main()
    GlobalHouseholdSurveys(FileStorage()).retrieve_survey_data()



