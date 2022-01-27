import S3Api
import glob
import codecs


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

    def store_raw_data_visualization(self):
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


if __name__ == '__main__':
    from dotenv import load_dotenv
    from FileStorage import FileStorage

    load_dotenv()

    climate_upload_service = ClimateUploadService(FileStorage(), S3Api.S3Api())

    print('Upload data to S3')
    climate_upload_service.store_raw_data_visualization()
