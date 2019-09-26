module "sample_topic" {
  source = "git@github.com:owner/terraform-modules.git"

  name  = "sample_topic"
  owner = "team"
}

resource "aws_sns_topic_policy" "sample_topic_policy_resource" {
  arn = "${module.sample_topic.arn}"

  policy = "${data.aws_iam_policy_document.sample_topic_policy.json}"
}

data "aws_iam_policy_document" "sample_topic_policy" {
  statement {
    sid = "Allow-different-AWS-account-to-subscribe-to-topic"

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::123456789:root"]
    }

    actions = [
      "SNS:Subscribe",
    ]

    resources = [
      "${module.sample_topic.arn}",
    ]
  }

  statement {
    sid = "Allow-this-AWS-account-to-publish-to-topic"

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::987654321:root"]
    }

    actions = [
      "SNS:Publish",
    ]

    resources = [
      "${module.sample_topic.arn}",
    ]
  }
}

module "streamalert_error_alarm" {
  source = "git@github.com:owner/terraform-modules.git/"

  name  = "streamalert_error_alarm"
  owner = "team"
}

resource "aws_sns_topic_subscription" "streamalert_gsuite_error_alarm_to_pagerduty" {
  topic_arn              = "${module.streamalert_error_alarm.arn}"
  protocol               = "https"
  endpoint               = "https://events.pagerduty.com/integration/xxxx/enqueue"
  endpoint_auto_confirms = true
}
