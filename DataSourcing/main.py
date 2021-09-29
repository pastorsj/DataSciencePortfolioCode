from dotenv import load_dotenv
from DataSourcingFactory import DataSourcingFactory
from CustomSearchData import CustomSearch

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
    print('[4] Retrieve raw household food security survey data for the global countries.')
    print('[5] Process raw household food security survey data for the global countries.')
    print('[6] Retrieve raw world development indicator data.')
    print('[q] Quit the program.')
    print('----------------')


if __name__ == '__main__':
    # print('Welcome to the data sourcing program. What would you like to do?')
    # main()
    CustomSearch().search()



