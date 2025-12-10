data "aws_caller_identity" "me" {}

# --------------------
# Networking (VPC)
# --------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-subnet" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  map_public_ip_on_launch = false
  tags = { Name = "${var.project_name}-private-subnet" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --------------------
# Security Groups
# --------------------
# Web SG - allow HTTP from anywhere, SSH restricted
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Allow HTTP and SSH (limited)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH (optional)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-web-sg" }
}

# DB SG - allow 3306 only from web SG
resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Allow MySQL only from web tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description       = "MySQL from web"
    from_port         = 3306
    to_port           = 3306
    protocol          = "tcp"
    security_groups   = [aws_security_group.web_sg.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-db-sg" }
}

# --------------------
# Key pair (optional)
# --------------------
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# --------------------
# IAM for RDS Enhanced Monitoring
# --------------------
resource "aws_iam_role" "rds_monitor_role" {
  name = "${var.project_name}-rds-monitor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitor_attach" {
  role       = aws_iam_role.rds_monitor_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# --------------------
# EC2 Web Instance
# --------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type_web
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/web_userdata.tpl", {
    cw_log_group = "/${var.project_name}/web-logs",
    cw_agent_config = "/opt/cwagentconfig.json"
  }))

  tags = {
    Name = "${var.project_name}-web-server"
  }
}

# --------------------
# CloudWatch Log Group for web logs
# --------------------
resource "aws_cloudwatch_log_group" "web_logs" {
  name              = "/${var.project_name}/web-logs"
  retention_in_days = 14
}

# --------------------
# RDS MySQL (managed)
# --------------------
resource "aws_db_subnet_group" "db_subnet" {
  name       = "${var.project_name}-db-subnet"
  subnet_ids = [aws_subnet.private.id]
  tags = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "mysql" {
  identifier              = "${var.project_name}-mysql"
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.db_instance_class
  username                = var.db_username
  password                = var.db_password
  skip_final_snapshot     = false
  publicly_accessible     = false
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnet.name

  # Enhanced monitoring for memory/disk metrics (interval sec)
  monitoring_interval     = 60
  monitoring_role_arn     = aws_iam_role.rds_monitor_role.arn

  tags = { Name = "${var.project_name}-rds-mysql" }
}

# --------------------
# CloudWatch Alarm & SNS
# --------------------
resource "aws_sns_topic" "alarm_topic" {
  name = "${var.project_name}-alerts"
}

# You may add subscriptions (email) via console or add resource aws_sns_topic_subscription

resource "aws_cloudwatch_metric_alarm" "high_cpu_web" {
  alarm_name          = "${var.project_name}-web-cpu-high"
  alarm_description   = "Triggers when web instance CPU > 70% for 2 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_sns_topic.alarm_topic.arn]
  dimensions = {
    InstanceId = aws_instance.web.id
  }
  treat_missing_data = "notBreaching"
}

# --------------------
# IAM: Support user + limited policy
# --------------------
data "aws_iam_policy_document" "support_policy_doc" {
  statement {
    sid     = "AllowStartStopForSpecificInstances"
    actions = ["ec2:StartInstances", "ec2:StopInstances", "ec2:RebootInstances"]
    resources = [
      aws_instance.web.arn,
      # add other instance ARNs if needed
    ]
  }

  statement {
    sid     = "AllowDescribeAndView"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:DescribeAlarms",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "AllowRDSDescribe"
    actions = [
      "rds:DescribeDBInstances",
      "rds:DescribeDBSnapshots"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "support_policy" {
  name   = "${var.project_name}-support-policy"
  policy = data.aws_iam_policy_document.support_policy_doc.json
}

resource "aws_iam_user" "support_user" {
  name = "support-user"
  tags = { Project = var.project_name }
}

resource "aws_iam_user_policy_attachment" "attach_support" {
  user       = aws_iam_user.support_user.name
  policy_arn = aws_iam_policy.support_policy.arn
}

resource "aws_iam_access_key" "support_key" {
  user = aws_iam_user.support_user.name
  # Warning: this will create access keys visible in state. For more secure usage, create console role or use federation.
}

# --------------------
# On-demand backups: EBS snapshot & RDS snapshot
# --------------------
resource "aws_ebs_snapshot" "web_root_snapshot" {
  description = "Initial snapshot of web root volume"
  volume_id   = aws_instance.web.root_block_device[0].volume_id
  tags = {
    Name = "${var.project_name}-web-root-snap"
  }
  depends_on = [aws_instance.web]
}

resource "aws_db_snapshot" "rds_snapshot" {
  db_instance_identifier = aws_db_instance.mysql.id
  db_snapshot_identifier = "${var.project_name}-initial-rds-snap"
  depends_on = [aws_db_instance.mysql]
}

# --------------------
# Outputs
# --------------------
output "web_public_ip" {
  description = "Public IP of the web server"
  value       = aws_instance.web.public_ip
}

output "rds_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = aws_db_instance.mysql.endpoint
}

output "support_user_access_key_id" {
  value = aws_iam_access_key.support_key.id
  sensitive = false
}

output "support_user_secret_access_key" {
  value     = aws_iam_access_key.support_key.secret
  sensitive = true
}
