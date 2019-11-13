# AWS CodePipeline Terraform 
An example project to run terraform code in an AWS CodePipeline project. 

## Contents
* buildspec.yml
* Makefile
* pipeline.yml
* terraform.tf
* tfvars.example

## Terraform
The terraform project creates an ecs cluster, service, task definition, auto scaling group, launch config etc, 
and an s3 backend to store the state of the infrastructure.

## Pipeline
The pipeline is quite simply a CodeCommit source and CodeBuild project. You can set the version of terraform to use
as a parameter to the CloudFormation template.

## Build Specification
The build specification downloads and installs terraform, and then runs the init, plan, apply commands as different
build stages. 

## Variables
Create a tfvars file and populate it with variables for your environment. The following are mandatory see example:

* public_subnets
* security_groups
* ami_id
* vpc_id 