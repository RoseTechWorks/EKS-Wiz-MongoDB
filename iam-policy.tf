resource "aws_iam_policy" "mongodb_ec2_full_access" {
  name        = "mongodb-ec2-full-access"
  description = "Overly permissive EC2 access for MongoDB VM (intentional)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ec2:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "mongodb_role" {
  name = "mongodb-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mongodb_attach" {
  role       = aws_iam_role.mongodb_role.name
  policy_arn = aws_iam_policy.mongodb_ec2_full_access.arn
}

resource "aws_iam_instance_profile" "mongodb_instance_profile" {
  name = "mongodb-instance-profile"
  role = aws_iam_role.mongodb_role.name
}
