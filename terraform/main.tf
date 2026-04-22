
module "networking" {
  source = "./modules/networking"
}


module "ecr" {
  source          = "./modules/ecr"
  repository_name = "simple-api-repo"
}


module "ecs" {
  source          = "./modules/ecs"
  vpc_id          = module.networking.vpc_id
  public_subnets  = module.networking.public_subnets
  private_subnets = module.networking.private_subnets
  

  container_image = "${module.ecr.repository_url}:latest"
  
  db_host         = module.database.db_address
  db_user         = "postgres_admin"
  db_password     = "SuaSenhaForte123"
  db_name         = "simpleapi"
}


module "database" {
  source      = "./modules/database"
  vpc_id      = module.networking.vpc_id
  db_subnets  = module.networking.private_subnets
  ecs_sg_id   = module.ecs.ecs_sg_id 
  db_name     = "simpleapi"
  db_user     = "postgres_admin"
  db_password = "SuaSenhaForte123" 
}


module "pipeline" {
  source = "./modules/pipeline"

  project_name          = "simple-api"
  environment           = "prod"
  aws_account_id        = "458580845911" 
  github_repo_id        = "EmanuelNerys/simple-api"
  github_connection_arn = "arn:aws:codeconnections:us-east-1:458580845911:connection/909f860d-fa85-4114-964d-19881000d9fd"
  
 
  ecr_repository_arn    = module.ecr.repository_arn
  ecr_repository_url    = module.ecr.repository_url
  ecs_cluster_name      = module.ecs.cluster_name
  ecs_service_name      = module.ecs.service_name
}

module "s3_backend" {
  source              = "./modules/s3_backend"
  state_bucket_name   = "emanuel-api-terraform-state"
  dynamodb_table_name = "terraform-state-lock"
}