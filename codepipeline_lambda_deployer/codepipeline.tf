resource "aws_codepipeline" "lambda-pipeline" {
  name     = "lambda-pipeline"
  role_arn = "${module.codepipeline_role.arn}"

  artifact_store {
    location = "${module.s3_codepipeline_artifacts.id}"
    type     = "S3"

    encryption_key {
      id   = "arn:aws:kms:us-east-1:${data.terraform_remote_state.shared.account_id}:alias/aws/s3"
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        Owner  = "Murty0"
        Repo   = "codepipeline-lambda-repo"
        Branch = "master"
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
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      version          = "1"

      configuration = {
        ProjectName = "${aws_codebuild_project.lambda-pipeline-build.id}"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "create-and-validate-changeset"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      input_artifacts = ["BuildArtifact"]
      version         = "1"
      run_order       = "1"

      configuration = {
        ActionMode    = "CHANGE_SET_REPLACE"
        StackName     = "lambda-pipeline-stack"
        ChangeSetName = "lambda-pipeline-changeset"
        TemplatePath  = "BuildArtifact::outputtemplate.yml"
        Capabilities  = "CAPABILITY_IAM"
        RoleArn       = "${module.codepipeline_role.arn}"
      }
    }

    action {
      name            = "execute-changeset"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      input_artifacts = ["BuildArtifact"]
      version         = "1"
      run_order       = "2"

      configuration = {
        ActionMode    = "CHANGE_SET_EXECUTE"
        StackName     = "lambda-pipeline-stack"
        ChangeSetName = "lambda-pipeline-changeset"
      }
    }
  }
}
