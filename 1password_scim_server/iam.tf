module "team" {
  source = "git@github.com:owner/terraform-modules.git"

  name               = "team"
  policy_type        = "AWS"
  policy_identifiers = ["arn:aws:iam::${data.terraform_remote_state.shared.bastion_account_id}:root"]
  mfa                = true
}

data "aws_iam_policy_document" "1password_op_scim_app" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeTags",
      "ec2:CreateTags",
    ]

    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${var.region}:${data.terraform_remote_state.shared.team_it_account_id}:secret:1password/scimsession-*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }
}

module "1password_op_scim_app_iam_role" {
  source = "git@github.com:owner/terraform-modules.git"

  name             = "op-scim-production"
  instance_profile = true

  policy = "${data.aws_iam_policy_document.1password_op_scim_app.json}"
}
