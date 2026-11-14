data "aws_ssm_parameter" "amazon_linux" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "jenkins_sg" {
  name        = "trendstore-jenkins-sg"
  description = "Restricted access for TrendStore Jenkins"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from administrator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Jenkins dashboard from administrator IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "Outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "trendstore-jenkins-sg"
    Environment = "Dev"
    Project     = "TrendStore"
  }
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ssm_parameter.amazon_linux.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins_profile.name
  associate_public_ip_address = true

  user_data = file("${path.module}/user_data.sh")

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = var.jenkins_instance_name
    Project     = "TrendStore"
    Environment = "Dev"
  }

  depends_on = [
    aws_iam_role_policy.jenkins_eks_policy
  ]
}
