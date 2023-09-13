import pytest
import pyspark
from pyspark import SparkContext, SparkConf
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from splink.spark.jar_location import similarity_jar_location
from delta import *
import sys
import pathlib

sys.path.append("/home/glue_user/workspace/src/glue/scripts")

from utils import *
from ingest_job import unique_by_merge_key, full_load, incremental_load

base_dir = pathlib.Path(__file__).parent.parent.resolve()


@pytest.fixture(scope="module", autouse=True)
def glue_context(request):

    sys.argv.append("--JOB_NAME")
    sys.argv.append("unit_testing")
    sys.argv.append("--datalake-formats")
    sys.argv.append("delta")

    args = getResolvedOptions(sys.argv, ["JOB_NAME"])

    conf = SparkConf()
    conf.set("spark.jars", similarity_jar_location())
    
    conf.set("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
    conf.set(
        "spark.sql.catalog.spark_catalog",
        "org.apache.spark.sql.delta.catalog.DeltaCatalog",
    )
    conf.set("spark.jars","/home/glue_user/workspace/src/glue/jars/delta-core_2.12-2.3.0.jar,/home/glue_user/workspace/src/glue/jars/delta-storage-2.3.0.jar")

    sc = SparkContext.getOrCreate(conf=conf)
    sc.setCheckpointDir(f"{base_dir}/tmp")
    context = GlueContext(sc)
    job = Job(context)
    job.init(args["JOB_NAME"], args)

    yield (context)

    job.commit()


# Tests for glue ingest job
def test_unique_by_merge_key(glue_context):
    pass


def test_partitioning(glue_context):
    pass

def test_full_load(glue_context):

    spark = glue_context.spark_session

    local_df = spark.read.parquet(
        f"{base_dir}/sample_data/source_data/bright_raw_agent_latest/"
    )

    target_path = f"{base_dir}/tmp/test_full_load/"

    unique_per_id = unique_by_merge_key(local_df,"membermlsid",["modificationtimestamp"])
    full_load(unique_per_id, target_path, test=True)

    writed_df = DeltaTable.forPath(spark, target_path).toDF()
    reference_df = DeltaTable.forPath(
        spark, f"{base_dir}/sample_data/raw_data/bright_raw_agent_latest/"
    ).toDF()

    writed_count = writed_df.count()
    ref_count = reference_df.count()

    assert (
        writed_count == ref_count
    ), f"writed df count expected to be {ref_count}, got: {writed_count}"
    assert (
        assert_schema(writed_df, reference_df) == True
    ), "full load df schema is not the same as the one expected"


def test_incremental_load(glue_context):
    pass


# Tests for glue splink cleaning job
def test_splink_clean_agent(glue_context):
    spark = glue_context.spark_session
    helper_test_splink_clean_data(
        "agent", spark, assert_counts={"raw": 100, "clean": 99}, base_dir=base_dir
    )

# def test_splink_clean_office(glue_context):
#     spark = glue_context.spark_session
#     helper_test_splink_clean_data(
#         "office", spark, assert_counts={"raw": 100, "clean": 98}, base_dir=base_dir
#     )

# def test_splink_clean_team(glue_context):
#     spark = glue_context.spark_session
#     helper_test_splink_clean_data(
#         "team", spark, assert_counts={"raw": 100, "clean": 5}, base_dir=base_dir
#     )

# # Tests for glue splink dedup job
# def test_splink_dedupe_agent(glue_context):
#     spark = glue_context.spark_session
#     helper_test_splink_dedup_data(
#         "agent", spark, assert_counts={"raw": 99, "dedup": 99}, base_dir=base_dir
#     )

# def test_splink_dedupe_office(glue_context):
#     spark = glue_context.spark_session
#     helper_test_splink_dedup_data(
#         "office", spark, assert_counts={"raw": 98, "dedup": 98}, base_dir=base_dir
#     )

# def test_splink_dedupe_team(glue_context):
#     spark = glue_context.spark_session
#     helper_test_splink_dedup_data(
#         "team", spark, assert_counts={"raw": 5, "dedup": 5}, base_dir=base_dir
#     )
