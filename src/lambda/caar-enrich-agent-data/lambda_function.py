from deltalake.writer import write_deltalake
import awswrangler as wr
import time
import logging
import os


# Env variables
s3_source_path = os.environ["S3_SOURCE_PATH"]
s3_target_path = os.environ["S3_TARGET_PATH"]

# Logger initialization
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

uoi_mapper = {"BRIGHT_CAAR":"A00001567", "Other":"M00000309"}

def lambda_handler(event, context):
    """
    Add county information for CAAR data and Unique Organization Id
    """

    start_time = time.time()

    # Read delta table from s3 path
    delta_table = wr.s3.read_deltalake(path = s3_source_path)

    end_time = time.time()
    logger.info("Read time: {}".format(end_time - start_time))
    start_time = end_time
    
    # Create Unique Organization Identifier column
    delta_table.loc[:,"uniqueorgid"] = delta_table.apply(lambda x: uoi_mapper.get(x.membersubsystemlocale,uoi_mapper["Other"]), axis=1)
    
    # Write delta lake table to s3
    write_deltalake(s3_target_path,
                    delta_table,
                    mode='overwrite',
                    overwrite_schema=True,
                    storage_options = {"AWS_S3_ALLOW_UNSAFE_RENAME":"true"})
    
    end_time = time.time()
    logger.info("Writing time: {}".format(end_time - start_time))
    start_time = end_time