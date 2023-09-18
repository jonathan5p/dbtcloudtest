# bdmp-oidh
Bright Data Management Platform - Organizations and Individuals Hub


<!-- # Testing

All testing for this project can be found under the *tests* folder in the root directory. The tests are separated into two parts, a set of tests for the glue jobs and another set of tests for the lambda functions.

To run the tests scripts for glue first we need to complete the Developing using a Docker image section in the [glue documentation page](https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming-etl-libraries.html) until the Running the container subsection. 

Run the following commands for preparation:

```bash
$ WORKSPACE_LOCATION=/home/jonathan.roncancio/Documents/Projects/BrightMLS/OIDH/bdmp-oidh/tests
$ UNIT_TEST_FILE_NAME=test_glue.py
$ PROFILE_NAME=aws_profile
```

```bash
docker run -it -v ~/.aws:/home/glue_user/.aws -v $WORKSPACE_LOCATION:/home/glue_user/workspace/ -e AWS_PROFILE=$PROFILE_NAME -e DISABLE_SSL=true --rm -p 4040:4040 -p 18080:18080 --name glue_pyspark public.ecr.aws/glue/aws-glue-libs:glue_libs_4.0.0_image_01 -c "python3 -m pytest" -->
```