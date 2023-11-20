from datetime import datetime, timedelta
from deltalake import write_deltalake
import pandas as pd
import numpy as np
import random
import pathlib
import json
import os

base_dir = pathlib.Path(__file__).parent.parent.resolve()
parent_folder = pathlib.Path(f"{base_dir}/generatedata/table_configs")

schema_files = [file.name for file in parent_folder.glob("*.json")]


def generate_data_for_column(data_type, num_rows, default_value, dynamic: bool = True):
    value = [default_value] * num_rows

    if dynamic:
        if data_type == "int":
            value = [i for i in range(1, num_rows + 1)]
        elif data_type in ["double", "float"]:
            value = np.random.uniform(low=0.0, high=50.5, size=num_rows)
        elif data_type == "string":
            value = [f"SAMPLE{i}" for i in range(1, num_rows + 1)]
        elif data_type == "boolean":
            value = [random.random() > 0.5 for i in range(1, num_rows + 1)]
        elif data_type == "date":
            start_date = datetime(2020, 1, 1, 12, 0, 0)
            value = [
                (start_date + timedelta(days=random.randint(0, 365))).date()
                for _ in range(num_rows)
            ]
        elif data_type in ["datetime", "timestamp"]:
            start_date = datetime(2020, 1, 1, 12, 0, 0)
            value = [
                (start_date + timedelta(days=random.randint(0, 365)))
                for _ in range(num_rows)
            ]
        elif data_type == "map":
            value = [[("key1", "value1"), ("key2", "value2")]] * num_rows
        else:
            value = ["NOT_VALID_TYPE"] * num_rows

    return value


def generate_parquet_data(table_config, output_file, format="parquet"):
    data = pd.DataFrame({})
    for field_name, field_config in table_config["fields"].items():
        data[field_name] = generate_data_for_column(
            data_type=field_config["type"],
            num_rows=table_config["n_rows"],
            default_value=field_config.get("default_value"),
            dynamic=field_config.get("dynamic", True),
        )

        if field_config["type"] in ["datetime", "timestamp"]:
            data[field_name] = pd.to_datetime(
                data[field_name], format="%Y-%m-%d %H:%M:%S"
            )

    if format == "delta":
        write_deltalake(output_file, data, mode="overwrite")
    else:
        os.makedirs(output_file, exist_ok=True)
        data.to_parquet(output_file / "table.parquet", index=False)


if __name__ == "__main__":
    schemas = {
        file_name.split(".")[0]: json.load(open(parent_folder / file_name))
        for file_name in schema_files
    }

    sort_fun = (
        lambda _schema: True
        if _schema[1].get("dependencies") != None
        and len(_schema[1].get("dependencies")) != 0
        else False
    )
    sorted_schemas = sorted(schemas.items(), key=sort_fun)

    for _, table_config in sorted_schemas:
        table_name = table_config["name"]
        output_file = base_dir / f"sample_data/{table_name}"
        generate_parquet_data(table_config, output_file, table_config["output_format"])
        print(
            f"Generated {table_config['n_rows']} rows of data for {table_name} with the specified schemas and saved to {output_file}."
        )
