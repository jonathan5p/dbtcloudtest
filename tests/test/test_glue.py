import pytest
from pyspark import SparkContext, SparkConf
from pyspark.sql import functions as F
import pyspark.pandas as ps
from datetime import datetime
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from splink.spark.jar_location import similarity_jar_location
from delta import *
import sys
import uuid
import pathlib

import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

base_dir = pathlib.Path(__file__).parent.parent.resolve()
parent_folder = pathlib.Path(f"{base_dir}/../src/mainprocess/glue")

for file in parent_folder.glob("*job"):
    job_path = str(file.absolute()) + "/"
    sys.path.append(job_path)
    logger.info(f"Path added to python path: {job_path}")

from utils import *
from ingestjob import unique_by_merge_key, full_load, incremental_load


@pytest.fixture(scope="module", autouse=True)
def glue_context():
    sys.argv.append("--JOB_NAME")
    sys.argv.append("unit_testing")
    sys.argv.append("--datalake-formats")
    sys.argv.append("delta")

    args = getResolvedOptions(sys.argv, ["JOB_NAME"])

    conf = SparkConf()

    conf.set("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
    conf.set(
        "spark.sql.catalog.spark_catalog",
        "org.apache.spark.sql.delta.catalog.DeltaCatalog",
    )
    conf.set(
        "spark.jars",
        f"{similarity_jar_location()},{str(parent_folder)}/jars/delta-core_2.12-2.3.0.jar,{str(parent_folder)}/jars/delta-storage-2.3.0.jar",
    )
    conf.set("spark.sql.catalogImplementation", "in-memory")

    sc = SparkContext.getOrCreate(conf=conf)
    sc.setCheckpointDir(f"{base_dir}/tmp")
    context = GlueContext(sc)
    job = Job(context)
    job.init(args["JOB_NAME"], args)

    yield (context)

    job.commit()


# Tests for glue ingest job
def test_unique_by_merge_key(glue_context):
    """
    Test that the unique_by_merge_key function defined
    in the OIDH glue ingest job works as expected.
    """
    spark = glue_context.spark_session

    local_df = spark.read.parquet(
        f"{base_dir}/sample_data/source_data/bright_raw_agent_latest/"
    )

    unique_per_id = unique_by_merge_key(
        local_df, "membermlsid", ["modificationtimestamp"]
    )

    unique_count = unique_per_id.count()
    ref_count = local_df.select(F.countDistinct("membermlsid")).collect()[0][0]

    assert (
        unique_count == ref_count
    ), f"Unique count expected to be {ref_count}, got: {unique_count}"


def test_full_load(glue_context):
    """
    Test that the full_load function defined
    in the OIDH glue ingest job works as expected.
    """
    spark = glue_context.spark_session

    local_df = spark.read.parquet(
        f"{base_dir}/sample_data/source_data/bright_raw_agent_latest/"
    )

    target_path = f"{base_dir}/tmp/test_full_load/"

    unique_per_id = unique_by_merge_key(
        local_df, "membermlsid", ["modificationtimestamp"]
    )
    full_load(unique_per_id, target_path, test=True)

    writed_df = DeltaTable.forPath(spark, target_path).toDF()
    reference_df = DeltaTable.forPath(
        spark, f"{base_dir}/sample_data/raw_data/bright_raw_agent_latest/"
    ).toDF()

    writed_count = writed_df.count()
    ref_count = reference_df.count()

    check_ts_sum = writed_df.select(
        F.sum(
            F.when(
                (F.col("dlingestionts") == F.col("dllastmodificationts")), 1
            ).otherwise(0)
        )
    ).collect()[0][0]

    assert (
        writed_count == ref_count
    ), f"writed df count expected to be {ref_count}, got: {writed_count}"
    assert (
        check_ts_sum == writed_count
    ), f"Not all dlingestion and dllastmodification timestamps are the same, expected {writed_count}, got: {check_ts_sum}"
    assert (
        assert_schema(writed_df, reference_df) == True
    ), "full load df schema is not the same as the one expected"


def test_incremental_load(glue_context):
    """
    Test that the incremental_load function defined
    in the OIDH glue ingest job works as expected.
    """
    spark = glue_context.spark_session

    local_df = spark.read.parquet(
        f"{base_dir}/sample_data/source_data/bright_raw_agent_latest/"
    )

    merge_key = "membermlsid"

    target_path = f"{base_dir}/tmp/test_full_load/"

    unique_per_id = unique_by_merge_key(local_df, merge_key, ["modificationtimestamp"])

    full_load(unique_per_id, target_path, test=True)

    changes_df = unique_per_id.limit(20).toPandas()
    changes_df.loc[:9, ["modificationtimestamp"]] = datetime.now()
    changes_df.loc[10:, [merge_key]] = changes_df[merge_key].apply(
        lambda x: str(uuid.uuid4())
    )
    changes_df = ps.from_pandas(changes_df).to_spark()

    incremental_load(
        spark,
        changes_df,
        target_path,
        merge_key,
        "source.modificationtimestamp > target.modificationtimestamp",
    )

    incremental_df = DeltaTable.forPath(spark, target_path).toDF()
    reference_df = DeltaTable.forPath(spark, target_path).toDF()

    writed_count = incremental_df.count()

    check_update_sum = incremental_df.select(
        F.sum(
            F.when(
                (F.col("dlingestionts") != F.col("dllastmodificationts")), 1
            ).otherwise(0)
        )
    ).collect()[0][0]

    check_insert_sum = incremental_df.select(
        F.sum(
            F.when(
                (F.col("dlingestionts") == F.col("dllastmodificationts")), 1
            ).otherwise(0)
        )
    ).collect()[0][0]

    assert (
        writed_count == 20
    ), f"writed df count expected to be {20}, got: {writed_count}"
    assert (
        check_update_sum == 10
    ), f"The process didn't update all the expected rows, expected {10}, got: {check_update_sum}"
    assert (
        check_insert_sum == 10
    ), f"The process didn't insert all the expected rows, expected {10}, got: {check_insert_sum}"
    assert (
        assert_schema(reference_df, incremental_df) == True
    ), "Incremental load df schema is not the same as the one expected"


# Tests for glue splink dedup job
def test_splink_dedupe_agent(glue_context):
    """
    Test that the deduplicate_entity function defined
    in the OIDH glue individuals dedup job works as expected
    for agent data.
    """
    spark = glue_context.spark_session
    helper_test_splink_dedup_data("agent", spark, base_dir=base_dir)


def test_splink_dedupe_office(glue_context):
    """
    Test that the deduplicate_entity function defined
    in the OIDH glue individuals dedup job works as expected
    for office data.
    """
    spark = glue_context.spark_session
    helper_test_splink_dedup_data("office", spark, base_dir=base_dir)
