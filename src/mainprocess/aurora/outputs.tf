output "sg_id" {
  value = aws_security_group.db_sg.id
}

output "subnetid" {
  value = data.aws_subnets.db_subnets.ids[0]
}

output "jdbc_url" {
  value = "jdbc:postgresql://${aws_rds_cluster.admintooldb.endpoint}:${local.db_port}/${local.db_name}"
}

