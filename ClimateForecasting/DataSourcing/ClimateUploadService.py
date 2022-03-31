import S3Api
import glob
import codecs
import pandas as pd


class ClimateUploadService:

    def __init__(self, file_storage, s3_api):
        """ Create a new instance of the ClimateUploadService class

        Parameters
        ----------
        :param file_storage: FileStorage, Required
            The file storage class used to store raw/processed data
        :param s3_api: S3_API, Required
            The S3 api wrapper class used to store data in AWS S3

        ----------
        """
        self._file_storage = file_storage
        self._s3_api = s3_api

    def store_raw_data_visualizations(self):
        print('Store raw data visualizations in S3')

        html_visualizations = list(glob.iglob(f'raw_data_visualizations/**/*.html', recursive=True))
        for file in html_visualizations:
            print('Opening file', file)
            contents = codecs.open(file, 'r')
            print('Attempting to upload raw data visualizations to s3')
            self._s3_api.upload_html(contents.read(), file.replace('raw_data_visualizations/', ''), S3Api.S3Location.RAW_DATA_VISUALIZATIONS)
            contents.close()

        png_visualizations = list(glob.iglob(f'raw_data_visualizations/**/*.png', recursive=True))
        for file in png_visualizations:
            print('Opening file', file)
            png = open(file, "rb")
            print('Attempting to upload raw data visualizations to s3')
            self._s3_api.upload_png(png, file.replace('raw_data_visualizations/', ''), S3Api.S3Location.RAW_DATA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            png.close()

        svg_visualizations = list(glob.iglob(f'raw_data_visualizations/**/*.svg', recursive=True))
        for file in svg_visualizations:
            print('Opening file', file)
            svg = open(file, "rb")
            print('Attempting to upload raw data visualizations to s3')
            self._s3_api.upload_svg(svg, file.replace('raw_data_visualizations/', ''), S3Api.S3Location.RAW_DATA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            svg.close()

    def store_cleaned_data_visualizations(self):
        print('Store cleaned data visualizations in S3')

        html_visualizations = list(glob.iglob(f'cleaned_data_visualizations/**/*.html', recursive=True))
        for file in html_visualizations:
            print('Opening file', file)
            contents = codecs.open(file, 'r')
            print('Attempting to upload cleaned data visualizations to s3')
            self._s3_api.upload_html(contents.read(), file.replace('cleaned_data_visualizations/', ''), S3Api.S3Location.CLEANED_DATA_VISUALIZATIONS)
            contents.close()

        png_visualizations = list(glob.iglob(f'cleaned_data_visualizations/**/*.png', recursive=True))
        for file in png_visualizations:
            print('Opening file', file)
            png = open(file, "rb")
            print('Attempting to upload cleaned data visualizations to s3')
            self._s3_api.upload_png(png, file.replace('cleaned_data_visualizations/', ''), S3Api.S3Location.CLEANED_DATA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            png.close()

        svg_visualizations = list(glob.iglob(f'cleaned_data_visualizations/**/*.svg', recursive=True))
        for file in svg_visualizations:
            print('Opening file', file)
            svg = open(file, "rb")
            print('Attempting to upload cleaned data visualizations to s3')
            self._s3_api.upload_svg(svg, file.replace('cleaned_data_visualizations/', ''), S3Api.S3Location.CLEANED_DATA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            svg.close()

        gif_visualizations = list(glob.iglob(f'cleaned_data_visualizations/**/*.gif', recursive=True))
        for file in gif_visualizations:
            print('Opening file', file)
            gif = open(file, "rb")
            print('Attempting to upload cleaned data visualizations to s3')
            self._s3_api.upload_gif(gif, file.replace('cleaned_data_visualizations/', ''), S3Api.S3Location.CLEANED_DATA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            gif.close()

    def store_cleaned_data(self):
        print('Store cleaned data in S3')
        csv_data = list(glob.iglob(f'cleaned_data/**/*.csv', recursive=True))
        for file in csv_data:
            print('Opening file', file)
            df = pd.read_csv(file)
            print('Attempting to upload cleaned data to s3')
            self._s3_api.upload_df(df, file.replace('cleaned_data/', ''), S3Api.S3Location.CLEANED_DATA)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')

    def store_eda_visualizations(self):
        print('Store eda visualizations in S3')

        png_visualizations = list(glob.iglob(f'eda_visualizations/**/*.png', recursive=True))
        for file in png_visualizations:
            print('Opening file', file)
            png = open(file, "rb")
            print('Attempting to upload eda visualizations to s3')
            self._s3_api.upload_png(png, file.replace('eda_visualizations/', ''), S3Api.S3Location.EDA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            png.close()

        svg_visualizations = list(glob.iglob(f'eda_visualizations/**/*.svg', recursive=True))
        for file in svg_visualizations:
            print('Opening file', file)
            svg = open(file, "rb")
            print('Attempting to upload eda visualizations to s3')
            self._s3_api.upload_svg(svg, file.replace('eda_visualizations/', ''), S3Api.S3Location.EDA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            svg.close()

    def store_arma_visualizations(self):
        print('Store arma visualizations in S3')

        png_visualizations = list(glob.iglob(f'arma_visualizations/**/*.png', recursive=True))
        for file in png_visualizations:
            print('Opening file', file)
            png = open(file, "rb")
            print('Attempting to upload arma visualizations to s3')
            self._s3_api.upload_png(png, file.replace('arma_visualizations/', ''), S3Api.S3Location.ARMA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            png.close()

        svg_visualizations = list(glob.iglob(f'arma_visualizations/**/*.svg', recursive=True))
        for file in svg_visualizations:
            print('Opening file', file)
            svg = open(file, "rb")
            print('Attempting to upload arma visualizations to s3')
            self._s3_api.upload_svg(svg, file.replace('arma_visualizations/', ''), S3Api.S3Location.ARMA_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            svg.close()

        csv_data = list(glob.iglob(f'arma_data/**/*.csv', recursive=True))
        for file in csv_data:
            print('Opening file', file)
            df = pd.read_csv(file)
            print('Attempting to upload arma data to s3')
            self._s3_api.upload_df(df, file.replace('arma_data/', ''), S3Api.S3Location.ARMA_DATA)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')

    def store_arch_visualizations(self):
        print('Store arch visualizations in S3')

        png_visualizations = list(glob.iglob(f'arch_visualizations/**/*.png', recursive=True))
        for file in png_visualizations:
            print('Opening file', file)
            png = open(file, "rb")
            print('Attempting to upload arch visualizations to s3')
            self._s3_api.upload_png(png, file.replace('arch_visualizations/', ''), S3Api.S3Location.ARCH_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            png.close()

        svg_visualizations = list(glob.iglob(f'arch_visualizations/**/*.svg', recursive=True))
        for file in svg_visualizations:
            print('Opening file', file)
            svg = open(file, "rb")
            print('Attempting to upload arch visualizations to s3')
            self._s3_api.upload_svg(svg, file.replace('arch_visualizations/', ''), S3Api.S3Location.ARCH_VISUALIZATIONS)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')
            svg.close()

        html_visualizations = list(glob.iglob(f'arch_visualizations/**/*.html', recursive=True))
        for file in html_visualizations:
            print('Opening file', file)
            contents = codecs.open(file, 'r')
            print('Attempting to upload cleaned data visualizations to s3')
            self._s3_api.upload_html(contents.read(), file.replace('arch_visualizations/', ''), S3Api.S3Location.ARCH_VISUALIZATIONS)
            contents.close()

        csv_data = list(glob.iglob(f'arch_data/**/*.csv', recursive=True))
        for file in csv_data:
            print('Opening file', file)
            df = pd.read_csv(file)
            print('Attempting to upload arch data to s3')
            self._s3_api.upload_df(df, file.replace('arch_data/', ''), S3Api.S3Location.ARCH_DATA)
            print('Uploading', file, 'to S3')
            print('Successfully uploaded')


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage

    load_dotenv()

    climate_upload_service = ClimateUploadService(FileStorage(), S3Api.S3Api())

    print('Upload data to S3')
    climate_upload_service.store_arma_visualizations()
