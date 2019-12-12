module "s3_codepipeline_artifacts" {
  source = "git@github.com:xxxx/terraform-modules.git//modules/s3?ref=v2.29.2"

  name = "codepipeline-artifacts"

  owner                 = "team-xxxx"
  personal_data         = "no"
  retention_policy_days = "indefinite"
}
