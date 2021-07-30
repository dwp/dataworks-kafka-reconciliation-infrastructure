data "aws_iam_role" "aws_batch_service_role" {
  name = "aws_batch_service_role"
}

# AWS Batch Job IAM role
data "aws_iam_policy_document" "batch_assume_policy" {
  statement {
    sid    = "BatchAssumeRolePolicy"
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      identifiers = ["ecs-tasks.amazonaws.com", ]

      type = "Service"
    }
  }
}
