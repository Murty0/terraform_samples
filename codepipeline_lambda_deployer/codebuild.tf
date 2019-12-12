resource "aws_codebuild_project" "lambda-pipeline-build" {
  name          = "lambda-pipeline-build"
  description   = "lambda-pipeline-build"
  build_timeout = "5"
  service_role  = "${module.codepipeline_role.arn}"

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:1.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  logs_config {
    cloudwatch_logs {
      group_name = "lambda-pipeline-build"
    }

    s3_logs {
      status   = "ENABLED"
      location = "arn:aws:s3:::codepipeline-artifacts"
    }
  }
}
