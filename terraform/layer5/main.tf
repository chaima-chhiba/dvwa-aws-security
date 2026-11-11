# LAYER 5 - Logging and monitoring added without changing the application deployment.
#
# Added in layer 2:
#   - self-signed certificate, uploaded to IAM (ACM is not available in the Learner Lab)
#   - HTTPS listener on 443 on the ALB; port 80 now only redirects to HTTPS
#   - ALB security group opens 443
# Limitation (say it in the report): TLS ends at the ALB, so ALB -> app traffic inside the VPC is HTTP.
#
# --- Layer 1 (unchanged) ---
# LAYER 1 - Network isolation.
#
# What changes compared with the baseline:
#   - app and database move into PRIVATE subnets (no public IP, no route in from the internet)
#   - the ALB in the public subnets is the ONLY entry point
#   - security groups are chained:  internet -> ALB (80) -> app (80) -> database (3306)
#   - a NAT gateway lets the private app pull its image and send logs, outbound only
#
# Security controls and remaining limitations:
#   - WAF is configured in waf.tf (layer 3 retained)
#   - DB credentials injected from Secrets Manager (layer 4)
#   - Security logging and alerting configured in logging.tf (layer 5)

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_iam_role" "lab" {
  name = "LabRole" # Learner Lab: the only role we can use for ECS
}

locals {
  name = "dvwa-layer1"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
}

# ---------------------------------------------------------------- network
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-igw" }
}

# Public subnets: only the ALB and the NAT gateway live here.
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index) # 10.0.0.0/24, 10.0.1.0/24
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name}-public-${count.index + 1}", Tier = "public" }
}

# Private app subnets: Fargate tasks. Outbound only, through the NAT gateway.
resource "aws_subnet" "app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10) # 10.0.10.0/24, 10.0.11.0/24
  availability_zone = local.azs[count.index]
  tags              = { Name = "${local.name}-app-${count.index + 1}", Tier = "private-app" }
}

# Private database subnets: no route to the internet at all.
resource "aws_subnet" "db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 20) # 10.0.20.0/24, 10.0.21.0/24
  availability_zone = local.azs[count.index]
  tags              = { Name = "${local.name}-db-${count.index + 1}", Tier = "private-db" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${local.name}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${local.name}-nat" }
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${local.name}-public-rt" }
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "${local.name}-app-rt" }
}

# The database route table has NO default route: nothing can reach out or in via the internet.
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-db-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "db" {
  count          = 2
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# ------------------------------------------------------- security groups
# Chain: internet -> ALB -> app -> database. Each tier only accepts the tier before it.
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "ALB - HTTP from the internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS from anywhere (layer 2)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name}-alb-sg" }
}

resource "aws_security_group" "app" {
  name        = "${local.name}-app-sg"
  description = "App - HTTP only from the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from the ALB security group only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name}-app-sg" }
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db-sg"
  description = "Database - MySQL only from the app"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from the app security group only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  tags = { Name = "${local.name}-db-sg" }
}

# --------------------------------------------------------------- database
resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.db[*].id
}

resource "aws_db_instance" "dvwa" {
  identifier              = "${local.name}-db"
  engine                  = "mariadb"
  engine_version          = "10.11"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_encrypted       = false # still weak: not a layer 1 topic
  db_name                 = "dvwa"
  username                = var.db_user
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  publicly_accessible     = false # FIXED in layer 1
  skip_final_snapshot     = true
  apply_immediately       = true
  backup_retention_period = 0
}

# -------------------------------------------------------------------- ECR
resource "aws_ecr_repository" "dvwa" {
  name                 = "dvwa"
  force_delete         = true
  image_tag_mutability = "MUTABLE"
}

# ------------------------------------------------------------------- ALB
resource "aws_lb" "main" {
  name               = "${local.name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  tags               = { Name = "${local.name}-alb" }
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name}-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip" # required for Fargate
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/login.php" # DVWA's "/" redirects, the login page returns 200
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 10
  }
}

# Self-signed certificate (lab only). The private key ends up in the Terraform state: fine for a lab,
# never do this in production. In production use ACM or a certificate from a real CA.
resource "tls_private_key" "alb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb" {
  private_key_pem       = tls_private_key.alb.private_key_pem
  validity_period_hours = 720
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
  dns_names             = [aws_lb.main.dns_name]

  subject {
    common_name  = aws_lb.main.dns_name
    organization = "TEK-UP DVWA lab"
  }
}

# Replacement for AWS Certificate Manager: an ALB listener can use a certificate stored in IAM.
resource "aws_iam_server_certificate" "alb" {
  provider         = aws.certificate
  name_prefix      = "${local.name}-cert-"
  certificate_body = tls_self_signed_cert.alb.cert_pem
  private_key      = tls_private_key.alb.private_key_pem

  lifecycle {
    create_before_destroy = true
  }
}

# Port 80 no longer serves the app: it only redirects to HTTPS.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Enable the HTTPS destination before switching HTTP to a redirect.
  depends_on = [aws_lb_listener.https]

  default_action {
    type             = "redirect"
    target_group_arn = null # Clear the previous forwarding action explicitly.
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_iam_server_certificate.alb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# -------------------------------------------------------------------- ECS
resource "aws_ecs_cluster" "main" {
  name = "${local.name}-cluster"
}

# Container stdout/stderr, for debugging only. Not the security logging of layer 5.
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}"
  retention_in_days = 1
}

resource "aws_ecs_task_definition" "dvwa" {
  family                   = "${local.name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = data.aws_iam_role.lab.arn
  task_role_arn            = data.aws_iam_role.lab.arn

  container_definitions = jsonencode([
    {
      name         = "dvwa"
      image        = "${aws_ecr_repository.dvwa.repository_url}:latest"
      essential    = true
      portMappings = [{ containerPort = 80, protocol = "tcp" }]

      # Layer 4: credentials injected by ECS from Secrets Manager at task startup.
      environment = [
        { name = "DB_SERVER", value = aws_db_instance.dvwa.address },
        { name = "DB_PORT", value = "3306" },
        { name = "DB_DATABASE", value = "dvwa" },


      ]

      secrets = [
        { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.db.arn}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db.arn}:password::" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "dvwa"
        }
      }
    }
  ])
}

# One task only, so the PHPSESSID cookie used by attacks.sh stays valid.
resource "aws_ecs_service" "dvwa" {
  # Preserve the existing service tag: HTTPS needs no ECS service update.
  # Learner Lab denies ecs:UpdateService.
  tags = { Stage = "layer1" }

  name                              = "${local.name}-svc"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.dvwa.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  platform_version                  = "1.4.0"
  health_check_grace_period_seconds = 120

  network_configuration {
    subnets          = aws_subnet.app[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false # FIXED in layer 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "dvwa"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.https, aws_route_table_association.app, aws_secretsmanager_secret_version.db, aws_secretsmanager_secret_policy.db]
}




