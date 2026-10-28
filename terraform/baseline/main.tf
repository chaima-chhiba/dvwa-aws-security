# BASELINE - intentionally vulnerable. Do not reuse outside the lab.
#
# Weaknesses on purpose (each one is fixed by a later layer):
#   - app and database in PUBLIC subnets, reachable from the internet   (layer 1)
#   - plain HTTP only, no TLS                                           (layer 2)
#   - no WAF in front of the app                                        (layer 3)
#   - DB credentials in plaintext environment variables                 (layer 4)
#   - no WAF / flow / audit logging or alerting                         (layer 5)

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_iam_role" "lab" {
  name = "LabRole" # Learner Lab: the only role we can use for ECS
}

locals {
  name = "dvwa-baseline"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
}

# ---------------------------------------------------------------- network
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true # needed so the public RDS endpoint resolves
  tags                 = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-igw" }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name}-public-${count.index + 1}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${local.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------- security groups
# WEAK ON PURPOSE: open to the whole internet.
resource "aws_security_group" "web" {
  name        = "${local.name}-web-sg"
  description = "DVWA - HTTP open to the world"
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
  tags = { Name = "${local.name}-web-sg" }
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db-sg"
  description = "Database - MySQL open to the world"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "MySQL from anywhere"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name}-db-sg" }
}

# --------------------------------------------------------------- database
resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.public[*].id
}

# MariaDB is DVWA's officially supported database and is MySQL-compatible
# (same protocol, same client). MySQL 8's default auth plugin often breaks the
# PHP driver in DVWA images. Switch engine to "mysql" only if you must.
resource "aws_db_instance" "dvwa" {
  identifier             = "${local.name}-db"
  engine                 = "mariadb"
  engine_version         = "10.11"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_encrypted      = false # weak on purpose
  db_name                = "dvwa"
  username               = var.db_user
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = true # weak on purpose
  skip_final_snapshot    = true
  apply_immediately      = true
  backup_retention_period = 0
}

# -------------------------------------------------------------------- ECR
resource "aws_ecr_repository" "dvwa" {
  name                 = "dvwa"
  force_delete         = true # lets 'terraform destroy' remove it with images inside
  image_tag_mutability = "MUTABLE"
}

# -------------------------------------------------------------------- ECS
resource "aws_ecs_cluster" "main" {
  name = "${local.name}-cluster"
}

# Container stdout/stderr, needed to debug the task. Not the security logging of layer 5.
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

      # WEAK ON PURPOSE: credentials in plaintext environment variables.
      # They show up in the task definition, in the console and in the API.
      environment = [
        { name = "DB_SERVER", value = aws_db_instance.dvwa.address },
        { name = "DB_PORT", value = "3306" },
        { name = "DB_DATABASE", value = "dvwa" },
        { name = "DB_USER", value = var.db_user },
        { name = "DB_PASSWORD", value = var.db_password },
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
  name            = "${local.name}-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.dvwa.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.web.id]
    assign_public_ip = true # weak on purpose
  }

  depends_on = [aws_route_table_association.public]
}
