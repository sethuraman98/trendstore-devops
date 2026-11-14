resource "aws_iam_role" "jenkins_role" {
  name = "trendstore-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "jenkins_eks_policy" {
  name = "trendstore-jenkins-eks-access"
  role = aws_iam_role.jenkins_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "trendstore-jenkins-profile"
  role = aws_iam_role.jenkins_role.name
}
