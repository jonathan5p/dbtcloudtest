[
  {
    "name": "oidh-push",
    "image": "${task_image}:latest",
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
          "awslogs-group": "${cloudwatch_log_group}",
          "awslogs-region": "${region}",
          "awslogs-stream-prefix": "ecs"
      }
    },
    "essential": true,
    "environment": [
      {
        "name": "athena_bucket",
        "value": "${athena_bucket_id}"
      },
      {
        "name": "oidh_table",
        "value": "${dynamo_table_register}"
      }
    ]
  }
]