import pandas as pd
import re
import matplotlib.pyplot as plt


class WDIIndicatorsProcessor:
    """Retrieve WDI Indicators from the World Bank"""

    def __init__(self):
        self._wdi_data = 'raw_data/wdi_data/wdi_data.csv'

    def visualize_wdi_data(self, statistic, country_code):
        """Simple visualization of wdi indicator data.

        For example, to see a chart of world population over time, the statistic would be SP.POP.TOTL and
        the country_code would be WLD
        """
        df = pd.read_csv(self._wdi_data)
        row = df.loc[(df['Country Code'] == country_code) & (df['Indicator Code'] == statistic)]
        year_re = re.compile(r'[0-9]{4}')
        x_values = [year for year in row.columns if bool(year_re.match(year))]
        y_values = [row[year].values[0] for year in x_values]

        plt.plot(x_values, y_values)
        plt.tick_params(axis='x', labelbottom=False)
        plt.xlabel('Years (1960-2020)')
        plt.ylabel('Population (in billions)')
        plt.title('World population over time')
        plt.show()

if __name__ == '__main__':
    WDIIndicatorsProcessor().visualize_wdi_data('SP.POP.TOTL', 'WLD')