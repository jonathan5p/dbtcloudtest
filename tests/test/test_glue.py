import pytest
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.sql import DataFrame
import sys
import json

sys.path.append("/home/glue_user/workspace/src/glue/scripts")
from cleaning_job import clean_splink_data


@pytest.fixture(scope="module", autouse=True)
def glue_context():
    sys.argv.append("--JOB_NAME")
    sys.argv.append("test_count")

    args = getResolvedOptions(sys.argv, ["JOB_NAME"])
    context = GlueContext(SparkContext.getOrCreate())
    job = Job(context)
    job.init(args["JOB_NAME"], args)

    yield (context)

    job.commit()

@pytest.fixture
def test_schema(df1: DataFrame, df2: DataFrame, check_nullable=True):
    field_list = lambda fields: (fields.name, fields.dataType, fields.nullable)
    fields1 = [*map(field_list, df1.schema.fields)]
    fields2 = [*map(field_list, df2.schema.fields)]
    if check_nullable:
        res = set(fields1) == set(fields2)
    else:
        res = set([field[:-1] for field in fields1]) == set(
            [field[:-1] for field in fields2]
        )
    return res


def test_splink_clean_agent(glue_context):
    spark = glue_context.spark_session
    agent_df = spark.read.parquet("/home/glue_user/workspace/tests/sample_data/staging_data/agent.parquet")

    cleaning_agent_config = json.load(
        open("/home/glue_user/workspace/tests/sample_configs/agent/cleaning_config.json")
    )
    print("Agent cleaning config: ", cleaning_agent_config)

    clean_df = clean_splink_data(
        agent_df, cleaning_agent_config, "dlid", clean_type="agent"
    )

    reference_df = spark.read.parquet(
        "/home/glue_user/workspace/tests/sample_data/consume_data/clean_agent.snappy.parquet"
    )

    raw_count = agent_df.count()
    clean_count = clean_df.count()

    assert raw_count == 1961, f"raw agent df count expected to be 0, got: {raw_count}"
    assert (
        clean_count == 1961
    ), f"clean agent df count expected to be 0, got: {clean_count}"
    assert (
        test_schema(clean_df, reference_df) == True
    ), "Agent clean df schema is not the same as the one expected"
