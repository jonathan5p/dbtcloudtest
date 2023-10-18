FROM public.ecr.aws/glue/aws-glue-libs:glue_libs_4.0.0_image_01

ARG JF_PIP_FILE
RUN mkdir ${HOME}/.pip

RUN echo "$JF_PIP_FILE" >> ${HOME}/.pip/pip.conf

RUN sed -i 's/^"//' ${HOME}/.pip/pip.conf;sed -i 's/"$//' ${HOME}/.pip/pip.conf;sed -i 's/\\n/\n/g' ${HOME}/.pip/pip.conf

RUN pip3 install boto3
RUN rm -rf ${HOME}/.pip/pip.conf

COPY app.py /

CMD ["python", "/app.py", "--s3_path", "abc"]