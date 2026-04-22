variable "project_name" {}
variable "environment" {}
variable "aws_account_id" {}
variable "github_repo_id" {}
variable "github_connection_arn" {}
variable "ecr_repository_arn" {}
variable "ecr_repository_url" {}
variable "ecs_cluster_name" {}
variable "ecs_service_name" {}
variable "container_name" {
  default = "api-container"
}