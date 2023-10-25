from pyspark.sql import DataFrame, SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import NullType
import json
from cleaningjob import clean_splink_data
from inddedupjob import deduplicate_entity as dedup_ind


def assert_schema(df1: DataFrame, df2: DataFrame, check_nullable=False):
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


def helper_test_splink_clean_data(
    entity: str, spark: SparkSession, assert_counts: list, base_dir: str
):
    local_df = spark.read.parquet(f"{base_dir}/sample_data/staging_data/{entity}/")

    if entity == "team":
        clean_agent_df = spark.read.parquet(
            f"{base_dir}/sample_data/consume_data/clean_agent/"
        )

        clean_office_df = spark.read.parquet(
            f"{base_dir}/sample_data/consume_data/clean_office/"
        )

    cleaning_config = json.load(
        open(f"{base_dir}/sample_configs/{entity}/cleaning_config.json")
    )
    print(f"{entity} cleaning config: ", cleaning_config)

    if entity == "team":
        clean_df = clean_splink_data(
            local_df,
            cleaning_config,
            "dlid",
            clean_type=entity,
            clean_agent_df=clean_agent_df,
            clean_office_df=clean_office_df,
        )
    else:
        clean_df = clean_splink_data(
            local_df, cleaning_config, "dlid", clean_type=entity
        )

    reference_df = spark.read.parquet(
        f"{base_dir}/sample_data/consume_data/clean_{entity}/"
    )

    raw_count = local_df.count()
    clean_count = clean_df.count()

    assert (
        raw_count == assert_counts["raw"]
    ), f"raw {entity} df count expected to be {assert_counts['raw']}, got: {raw_count}"
    assert (
        clean_count == assert_counts["clean"]
    ), f"clean {entity} df count expected to be {assert_counts['clean']}, got: {clean_count}"
    assert (
        assert_schema(clean_df, reference_df) == True
    ), f"{entity} clean df schema is not the same as the one expected"


def helper_test_splink_dedup_data(
    entity: str, spark: SparkSession, assert_counts: list, base_dir: str
):
    local_df = spark.read.parquet(
        f"{base_dir}/sample_data/consume_data/clean_{entity}/"
    )

    splink_config = json.load(
        open(f"{base_dir}/sample_configs/{entity}/splink_config.json")
    )
    print(f"{entity} splink config: ", splink_config)

    cluster_df = dedup_ind(
        entity=entity,
        spark_df=local_df,
        splink_config=splink_config,
        splink_model_path=f"{base_dir}/sample_configs/{entity}/splink_model.json",
        spark=spark,
    )

    if entity=='office':
        cluster_df = cluster_df.withColumn("orgsourcetype", F.lit("OFFICE"))
    elif entity=='team':
        cluster_df = cluster_df.withColumn("orgsourcetype", F.lit("TEAM"))

    cluster_reference_df = spark.read.parquet(
        f"{base_dir}/sample_data/consume_data/dedupe_{entity}_df/"
    )

    raw_count = cluster_df.count()
    dedup_count = cluster_reference_df.count()

    for field in cluster_df.schema.fields:
        if field.dataType == NullType():
            cluster_df = cluster_df.withColumn(field.name,F.col(field.name).cast('string'))

    assert (
        raw_count == assert_counts["raw"]
    ), f"raw {entity} df count expected to be {assert_counts['raw']}, got: {raw_count}"
    assert (
        dedup_count == assert_counts["dedup"]
    ), f"deduped {entity} df count expected to be {assert_counts['dedup']}, got: {dedup_count}"
    assert (
        assert_schema(cluster_df, cluster_reference_df) == True
    ), f"{entity} dedup df schema is not the same as the one expected"
