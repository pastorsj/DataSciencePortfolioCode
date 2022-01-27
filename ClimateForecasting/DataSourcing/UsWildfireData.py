import S3Api
import pandas as pd
import sqlite3
import matplotlib.pyplot as plt


class UsWildfireData:

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the UsWildfireData class

        Parameters
        ----------
        :param file_storage: FileStorage, Required
            The file storage class used to store raw/processed data
        :param s3_api: S3_API, Required
            The S3 api wrapper class used to store data in AWS S3

        ----------
        """
        self._wildfire_endpoint = 'https://www.fs.usda.gov/rds/archive/products/RDS-2013-0009.5/RDS-2013-0009.5_SQLITE.zip'
        self._file_storage = file_storage
        self._s3_api = s3_api
        self._file_storage.create_directory_if_not_exists('raw_data_visualizations/usda/')

    def retrieve_wildfire_data_sql(self):
        conn = sqlite3.connect('raw_data/usda/wildfire_data.sqlite')
        fires_df = pd.read_sql("""
            SELECT SOURCE_SYSTEM_TYPE, SOURCE_SYSTEM, FIRE_CODE, FIRE_NAME, COMPLEX_NAME, FIRE_YEAR, 
            DISCOVERY_DATE, DISCOVERY_DOY, DISCOVERY_TIME, DISCOVERY_TIME, STAT_CAUSE_CODE, 
            STAT_CAUSE_DESCR, CONT_DATE, CONT_DOY, CONT_TIME, FIRE_SIZE, FIRE_SIZE_CLASS, LATITUDE,
            LONGITUDE, OWNER_CODE, OWNER_DESCR, STATE, COUNTY, FIPS_CODE, FIPS_NAME
            FROM fires""", con=conn)
        print(fires_df.head())
        print(len(fires_df))
        print(fires_df.columns)
        self._file_storage.store_df_as_file('usda/wildfire_data.csv', fires_df)

    def visualize_raw_wildfire_data(self):
        wildfire_df = pd.read_csv('raw_data/usda/wildfire_data.csv')
        print(wildfire_df.head())
        print('Aggregating wildfires over years')

        print(wildfire_df.groupby(['FIRE_YEAR']).size())
        print('Plotting...')
        wildfire_agg_df = wildfire_df.groupby(['FIRE_YEAR']).size().reset_index(name='counts')
        plt.figure()
        plt.plot(wildfire_agg_df['FIRE_YEAR'], wildfire_agg_df['counts'], color="red")
        plt.xlabel('Year (1992-2015)')
        plt.ylabel('Number of Recorded Wildfires')
        plt.title('Wildfires over time (United States)')
        plt.savefig('raw_data_visualizations/usda/wildfires_over_times.svg', format='svg')
        plt.savefig('raw_data_visualizations/usda/wildfires_over_times.png')
        plt.show()


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage
    load_dotenv()

    noaa_data_sourcing_instance = UsWildfireData(FileStorage(), S3Api.S3Api())

    print('Retrieving raw wildfire data')
    noaa_data_sourcing_instance.visualize_raw_wildfire_data()

