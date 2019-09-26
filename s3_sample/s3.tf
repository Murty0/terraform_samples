module "s3_sample" {
  source = "git@github.com:owner/terraform-modules.git"

  name = "logs_bucket"

  bucket_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "Policy1233455",
  "Statement": [
    {
      "Sid": "Stmt1234456",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::1232455677:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::logs.owner/*"
    }
  ]
}
POLICY
  lifecycle_rules = [
    {
      id      = "Age out old logs"
      enabled = true

      noncurrent_version_expiration = [{
        days = 445
      }]

      expiration = [{
        days = 445
      }]
    },
  ]
  personal_data         = "no"
  retention_policy_days = "indefinite"
  owner                 = "team"
}
