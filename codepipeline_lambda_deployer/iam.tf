data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:us-east-1:${data.terraform_remote_state.shared.account_id}:log-group:*"]
  }

  statement {
    effect = "Allow"

    actions = ["kms:*"]

    resources = ["arn:aws:kms:us-east-1:${data.terraform_remote_state.shared.account_id}:alias/aws/s3"]
  }

  statement {
    effect = "Allow"

    actions = [
      "cloudformation:CreateStack",
      "cloudformation:DeleteStack",
      "cloudformation:DescribeStacks",
      "cloudformation:UpdateStack",
      "cloudformation:CreateChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:DescribeChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:SetStackPolicy",
      "cloudformation:ValidateTemplate",
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "events:*",
      "iam:GetRole",
      "iam:PassRole",
      "lambda:*",
    ]

    resources = ["*"]
  }
}

module "codepipeline_role" {
  source = "git@github.com:xxxx/terraform-modules.git//modules/iam/role?ref=v2.29.2"

  name = "codepipeline-role"

  policy_identifiers = [
    "cloudformation.amazonaws.com",
    "codebuild.amazonaws.com",
    "codepipeline.amazonaws.com",
  ]

  policies = {
    "codepipeline_policy" = "${data.aws_iam_policy_document.codepipeline_policy.json}"
    "aws_s3_limited"         = "${module.policies.aws_s3_limited}"
  }
}
