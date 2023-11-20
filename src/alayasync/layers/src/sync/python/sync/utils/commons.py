
def get_key(id, bucket):

    return id.replace(f's3://{bucket}/', '')


def get_source_file(source_key):

    return '.'.join(source_key.split('/')[-1].split('.')[0:-1])