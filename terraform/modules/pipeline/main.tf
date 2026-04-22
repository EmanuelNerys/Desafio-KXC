
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "pipeline-artifacts-${var.project_name}-${var.aws_account_id}"
  force_destroy = true
}


resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "codebuild.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Effect = "Allow", Resource = "*" },
      { Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"], Effect = "Allow", Resource = "${aws_s3_bucket.pipeline_artifacts.arn}/*" },
      { Action = ["ecr:GetAuthorizationToken"], Effect = "Allow", Resource = "*" },
      { Action = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload"], Effect = "Allow", Resource = "*" }
    ]
  })
}


resource "aws_codebuild_project" "project" {
  name          = "${var.project_name}-build"
  service_role  = aws_iam_role.codebuild_role.arn
  
  artifacts { 
    type = "CODEPIPELINE" 
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }

    environment_variable {
      name  = "REPOSITORY_URI"
      value = var.ecr_repository_url
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}


resource "aws_iam_role" "pipeline_role" {
  name = "${var.project_name}-pipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "codepipeline.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "pipeline_policy" {
  role = aws_iam_role.pipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Action = ["s3:GetObject", "s3:PutObject", "s3:GetBucketVersioning"], Effect = "Allow", Resource = "*" },
      { Action = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"], Effect = "Allow", Resource = "*" },
      { Action = ["codestar-connections:UseConnection"], Effect = "Allow", Resource = var.github_connection_arn },
      { Action = ["ecs:*", "iam:PassRole"], Effect = "Allow", Resource = "*" }
    ]
  })
}

# CodePipeline V2
resource "aws_codepipeline" "pipeline" {
  name          = "${var.project_name}-pipeline"
  role_arn      = aws_iam_role.pipeline_role.arn
  pipeline_type = "V2" 

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  # Configuração de Gatilho (Trigger) para Pipeline V2
  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "Source"
      push {
        branches {
          includes = ["main"]
        }
      }
    }
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = var.github_repo_id
        BranchName       = "main"
      
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration    = { ProjectName = aws_codebuild_project.project.name }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      version         = "1"
      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.ecs_service_name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

