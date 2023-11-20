
variable "base_naming" {

}

variable "project_prefix" {
  description = "This is part of bright naming convention belongs to project repo and resources purpose"
}

variable "conn_name" {
  description = "Glue connection name"
}

variable "password" {
  description = "Glue connection db password"
  default     = ""
}

variable "username" {
  description = "Glue connection db username"
  default     = ""
}

variable "jdbc_url" {
  description = "Glue connection db JDBC url"
  default     = ""
}

variable "subnet_id" {
  description = "Glue connection subnet id"
}

variable "security_group_id_list" {
  description = "Glue connection db security groups"
  type        = list(any)
  default     = []
}

variable "connection_type" {
  description = "Glue connection type"
  default     = "JDBC"
}