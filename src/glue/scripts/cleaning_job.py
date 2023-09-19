import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
import boto3
import json
from clean.full_run import CleanAgentOfficeRecords, CleanTeamRecords
from pyspark.sql import DataFrame


def clean_splink_data(
    data_df: DataFrame, configs: dict, unique_id_key: str, clean_type: str, **kwargs
):
    """
    Clean splink data
    """
    clean_df = None

    if clean_type in ["agent", "office"]:
        clean_df = CleanAgentOfficeRecords(data_df, configs, unique_id_key)

    elif clean_type == "team":
        clean_df = CleanTeamRecords(
            data_df,
            configs,
            unique_id_key,
            kwargs["clean_agent_df"],
            kwargs["clean_office_df"],
        )

    else:
        raise ValueError(f"Invalid type: {type}")

    return clean_df

if __name__ == '__main__':
    params = [
        "JOB_NAME",
        "config_bucket",
        "model_version",
        "data_bucket",
        "glue_db",
        "agent_table_name",
        "office_table_name",
        "team_table_name",
    ]

    args = getResolvedOptions(sys.argv, params)

    sc = SparkContext()
    glueContext = GlueContext(sc)
    spark = glueContext.spark_session
    job = Job(glueContext)
    job.init(args["JOB_NAME"], args)

    # Load delta tables for agents, offices and teams
    agent_df = spark.read.format("delta").load(f"s3://{args['data_bucket']}/staging_data/{args['glue_db']}/{args['agent_table_name']}/")
    office_df = spark.read.format("delta").load(f"s3://{args['data_bucket']}/staging_data/{args['glue_db']}/{args['office_table_name']}/")
    team_df = spark.read.format("delta").load(f"s3://{args['data_bucket']}/raw_data/{args['glue_db']}/{args['team_table_name']}/")

    # Download config files for agents, offices and team
    s3 = boto3.client("s3")
    s3.download_file(
        args["config_bucket"],
        f'agent/version_{args["model_version"]}/cleaning_config.json',
        f"/tmp/cleaning_agent_config.json",
    )
    s3.download_file(
        args["config_bucket"],
        f'office/version_{args["model_version"]}/cleaning_config.json',
        f"/tmp/cleaning_office_config.json",
    )
    s3.download_file(
        args["config_bucket"],
        f'team/version_{args["model_version"]}/cleaning_config.json',
        f"/tmp/cleaning_team_config.json",
    )

    cleaning_agent_config = json.load(open("/tmp/cleaning_agent_config.json"))
    print(cleaning_agent_config)

    cleaning_office_config = json.load(open("/tmp/cleaning_office_config.json"))
    print(cleaning_office_config)

    cleaning_team_config = json.load(open("/tmp/cleaning_team_config.json"))
    print(cleaning_team_config)

    # Clean the data for agent, offices and teams
    clean_agent_df = clean_splink_data(
        agent_df, cleaning_agent_config, "dlid", clean_type="agent"
    )
    clean_office_df = clean_splink_data(
        office_df, cleaning_office_config, "dlid", clean_type="office"
    )
    clean_team_df = clean_splink_data(
        team_df,
        cleaning_team_config,
        "dlid",
        clean_type="team",
        clean_agent_df=clean_agent_df,
        clean_office_df=clean_office_df,
    )

    # Write the clean data to S3
    clean_agent_df.write.mode("overwrite")\
        .format("parquet")\
        .option("path", f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/clean_splink_agent_data/")\
        .option("overwriteSchema", "true")\
        .option("compression", "snappy")\
        .saveAsTable(f"{args['glue_db']}.clean_splink_agent_data")
        
    clean_office_df.write.mode("overwrite")\
        .format("parquet")\
        .option("path", f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/clean_splink_office_data/")\
        .option("overwriteSchema", "true")\
        .option("compression", "snappy")\
        .saveAsTable(f"{args['glue_db']}.clean_splink_office_data")
        
    clean_team_df.write.mode("overwrite")\
        .format("parquet")\
        .option("path", f"s3://{args['data_bucket']}/consume_data/{args['glue_db']}/clean_splink_team_data/")\
        .option("overwriteSchema", "true")\
        .option("compression", "snappy")\
        .saveAsTable(f"{args['glue_db']}.clean_splink_team_data")
    
    job.commit()