output "primary_keys" {
    value = {
        "individuals" : module.individuals.primary_key
        "organizations" : module.organizations.primary_key
    }
}