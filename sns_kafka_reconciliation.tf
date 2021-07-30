resource "aws_sns_topic" "kafka_reconciliation_topic" {
  name = "kafka_reconciliation"

  tags = {
    Name = "kafka_reconciliation"
  }
}

resource "aws_sns_topic_policy" "kafka_reconciliation_topic_messages" {
  arn    = aws_sns_topic.kafka_reconciliation_topic.arn
  policy = data.aws_iam_policy_document.kafka_reconciliation_topic_policy.json
}

data "aws_iam_policy_document" "kafka_reconciliation_topic_policy" {
  policy_id = "KafkaReconciliationSnsTopicPolicy"

  statement {
    sid = "DefaultPolicy"

    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish",
      "SNS:Receive",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        local.accounts[local.environment],
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.kafka_reconciliation_topic.arn,
    ]
  }

  statement {
    sid = "AllowCloudwatchEventsToPublishToTopic"

    actions = [
      "SNS:Publish",
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [
      aws_sns_topic.kafka_reconciliation_topic.arn,
    ]
  }
}

output "kafka_reconciliation_topic" {
  value = {
    arn = aws_sns_topic.kafka_reconciliation_topic.arn
  }
}
