# bdmp-oidh
Bright Data Management Platform - Organizations and Individuals Hub


# Testing

All testing for this project can be found under the *tests* folder in the root directory. The tests are separated into two parts, a set of tests for the glue jobs and another set of tests for the lambda functions.

## Glue tests
To run the tests scripts for glue first we need to complete the Developing using a Docker image section in the [glue documentation page](https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming-etl-libraries.html) until the Running the container subsection. 

Run the following commands for preparation:

```bash
$ WORKSPACE_LOCATION=YOUR_OWN_HOME_PATH/bdmp-oidh/tests
$ UNIT_TEST_FILE_NAME=test_glue.py
$ PROFILE_NAME=your_aws_profile
```

After the variables are set, you can run this docker command to run the glue tests

```bash
docker run -it -v ~/.aws:/home/glue_user/.aws -v $WORKSPACE_LOCATION:/home/glue_user/workspace/ -e AWS_PROFILE=$PROFILE_NAME -e DISABLE_SSL=true --rm -p 4040:4040 -p 18080:18080 --name glue_pyspark public.ecr.aws/glue/aws-glue-libs:glue_libs_4.0.0_image_01 -c "pip install -r glue_requirements.txt; python3 -m pytest test/test_glue.py"
```

## Lambda tests

Lambda tests are way easier! You just need to install the ***lambda_requirements.txt*** file in your local python env and then run 

```bash
python3 -m pytest test/test_lambda.py.
```