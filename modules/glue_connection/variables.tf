
variable "base_naming"{

}

variable "project_prefix"{

}

variable "conn_name"{

}

variable "password"{
    description = "Glue connection db password"
}

variable "username"{
    description = "Glue connection db username"
}

variable "jdbc_url"{
    description = "Glue connection db JDBC url"
}

variable "subnet_id"{
    description = "Glue connection subnet id"
}

variable "security_group_id_list"{
    description = "Glue connection db security groups"
    default = []
}