# bdmp-oidh
Bright Data Management Platform - Organizations and Individuals Hub


# Testing

All testing for this project can be found under the *tests* folder in the root directory.

## Glue tests
To run the tests scripts for glue first we need to complete the **Developing using a Docker image** section in the [glue documentation page](https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming-etl-libraries.html) until the Running the container subsection. 

Run the following commands for preparation:

```bash
$ WORKSPACE_LOCATION=YOUR_OWN_HOME_PATH/bdmp-oidh/
$ PROFILE_NAME=YOUR_AWS_PROFILE_NAME
```

After the variables are set, you can run this docker command to run the glue tests

```bash
docker run -it -v ~/.aws:/home/glue_user/.aws -v $WORKSPACE_LOCATION:/home/glue_user/workspace/ -e AWS_PROFILE=$PROFILE_NAME -e DISABLE_SSL=true --rm --name glue_pyspark public.ecr.aws/glue/aws-glue-libs:glue_libs_4.0.0_image_01 -c "pip3 install -r tests/glue_requirements.txt; python3 tests/generatedata/data_gen.py; python3 -m pytest tests/test/test_glue.py"
```