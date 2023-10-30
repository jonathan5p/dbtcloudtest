output "conn_name" {
  value = aws_glue_connection.glue_connection.name
}

output "conn_sg_id" {
  value = length(var.security_group_id_list)==0 ? aws_security_group.conn_sg[0].id : null
}