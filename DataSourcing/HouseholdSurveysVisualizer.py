import pandas as pd
import matplotlib.pyplot as plt

class HouseholdSurveysProcessor:

    def visualize_raw_data(self, filename, state):
        file = f'processed_data/survey_data/standard/all/{filename}.csv'
        df = self._retrieve_raw_survey_data(file)
        self._visualize_state(df, state)
        print(df.head())

    def _retrieve_raw_survey_data(self, filename):
        return pd.read_csv(filename)

    def _visualize_state(self, df, state):
        fig1, ax = plt.subplots()
        labels = ['Enough of the kinds\n of food wanted',
                  'Enough food but not\n always the kinds wanted',
                  'Sometimes not enough\n to eat',
                  'Often not enough\n to eat',
                  'Did not report']
        values = df.loc[df['State'] == state].values.tolist()
        ax.pie(values[0][2:], labels=labels, startangle=90)
        ax.set_title('Week 17, Food Security Household Surveys (Census), California')

        plt.show()

if __name__ == '__main__':
    HouseholdSurveysProcessor().visualize_raw_data('Week 17', 'CA')