import pytest
from pyspark import SparkContext, SparkConf
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from splink.spark.jar_location import similarity_jar_location
import sys
import pathlib

sys.path.append("/home/glue_user/workspace/src/glue/scripts")

from utils import *

base_dir = pathlib.Path(__file__).parent.parent.resolve()


@pytest.fixture(scope="module", autouse=True)
def glue_context():
    sys.argv.append("--JOB_NAME")
    sys.argv.append("unit_testing")

    args = getResolvedOptions(sys.argv, ["JOB_NAME"])

    conf = SparkConf()
    conf.set("spark.jars", similarity_jar_location())
    sc = SparkContext.getOrCreate(conf=conf)
    sc.setCheckpointDir(f"{base_dir}/tmp")
    context = GlueContext(sc)
    job = Job(context)
    job.init(args["JOB_NAME"], args)

    yield (context)

    job.commit()

def test_splink_clean_agent(glue_context):
    spark = glue_context.spark_session
    helper_test_splink_clean_data(
        "agent", spark, assert_counts={"raw": 100, "clean": 99}, base_dir=base_dir
    )

def test_splink_clean_office(glue_context):
    spark = glue_context.spark_session
    helper_test_splink_clean_data(
        "office", spark, assert_counts={"raw": 100, "clean": 98}, base_dir=base_dir
    )

def test_splink_clean_team(glue_context):
    spark = glue_context.spark_session
    helper_test_splink_clean_data(
        "team", spark, assert_counts={"raw": 100, "clean": 5}, base_dir=base_dir
    )

def test_splink_dedupe_agent(glue_context):
    spark = glue_context.spark_session
    helper_test_splink_dedup_data(
        "agent", spark, assert_counts={"raw": 99, "dedup": 99}, base_dir=base_dir
    )

def test_splink_dedupe_office(glue_context):
    spark = glue_context.spark_session
    helper_test_splink_dedup_data(
        "office", spark, assert_counts={"raw": 98, "dedup": 98}, base_dir=base_dir
    )

def test_splink_dedupe_team(glue_context):
    spark = glue_context.spark_session
    helper_test_splink_dedup_data(
        "team", spark, assert_counts={"raw": 5, "dedup": 5}, base_dir=base_dir
    )