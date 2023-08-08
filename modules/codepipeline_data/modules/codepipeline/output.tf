output "cbd_build_naming" {
    value = module.cbd_build_naming.name
}

output "codebuild_project_build_arn" {
    value = aws_codebuild_project.build.arn
}

output "codebuild_project_provision_arn" {
    value = aws_codebuild_project.provision.arn
}