import sys
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions


class GluePythonSampleTest:
    def __init__(self):
        params = []
        if '--JOB_NAME' in sys.argv:
            params.append('JOB_NAME')
        args = getResolvedOptions(sys.argv, params)

        self.context = GlueContext(SparkContext.getOrCreate())
        self.job = Job(self.context)
        self.spark = self.context.spark_session

        if 'JOB_NAME' in args:
            jobname = args['JOB_NAME']
        else:
            jobname = "test"
        self.job.init(jobname, args)

    def run(self):

        df = self.spark.read.format("parquet").load("/home/glue_user/workspace/tests/sample_data/consume_data/clean_team.parquet")

        df.printSchema()
        print(df.show(5))
        print(df.count())


if __name__ == '__main__':
    GluePythonSampleTest().run()
