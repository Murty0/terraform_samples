module "sample_queue" {
  source = "git@github.com:owner/terraform-modules.git"

  name  = "sample_queue"
  owner = "team"

  visibility_timeout_seconds = 300
}

# Setup policy for sample queue to allow SNS in different AWS account to publish events to it

resource "aws_sqs_queue_policy" "sqs_send_message_policy" {
  queue_url = "${module.sqs.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${module.sqs.arn}",
      "Condition": {
        "ArnEquals": { "aws:SourceArn": "arn:aws:sns:us-east-1:${data.terraform_remote_state.shared.streamalert_account_id}:sample_topic" }
      }
    }
  ]
}
POLICY
}
