provider "aws" {
  region = "ap-southeast-1"
}

# -------------------
# VPC
# -------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-1a"
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-1b"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.rt.id
}

# -------------------
# Security Group
# -------------------
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------
# DynamoDB
# -------------------
resource "aws_dynamodb_table" "app" {
  name         = "AppRegister"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "appId"

  attribute {
    name = "appId"
    type = "S"
  }
}

# -------------------
# SNS
# -------------------
resource "aws_sns_topic" "app" {
  name = "AppRegistrationTopic"
}

# -------------------
# ECR
# -------------------
resource "aws_ecr_repository" "app" {
  name         = "app-register"
  force_delete = true
}

# -------------------
# ECS Cluster
# -------------------
resource "aws_ecs_cluster" "app" {
  name = "app-cluster"
}

# -------------------
# IAM Roles
# -------------------
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 👉 TASK ROLE (QUAN TRỌNG)
resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb_access" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "sns_access" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# -------------------
# CloudWatch Logs
# -------------------
resource "aws_cloudwatch_log_group" "app" {
  name = "/ecs/app"
}

# -------------------
# ECS Task Definition
# -------------------
resource "aws_ecs_task_definition" "app" {
  family                   = "app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${aws_ecr_repository.app.repository_url}:latest"

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "/ecs/app",
          awslogs-region        = "ap-southeast-1",
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# -------------------
# Load Balancer
# -------------------
resource "aws_lb" "app" {
  name               = "app-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  security_groups    = [aws_security_group.app_sg.id]
}

resource "aws_lb_target_group" "app" {
  name        = "app-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path = "/"
    port = "3000"
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# -------------------
# ECS Service
# -------------------
resource "aws_ecs_service" "app" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.app_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.app]
}

# -------------------
# SQS FIFO (Log Queue)
# -------------------
resource "aws_sqs_queue" "log_queue" {
  name                        = "log-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true

  visibility_timeout_seconds  = 30
  message_retention_seconds   = 86400 # 1 ngày

  receive_wait_time_seconds   = 10 # long polling
}

# -------------------
# SQS DLQ
# -------------------
resource "aws_sqs_queue" "log_dlq" {
  name       = "log-dlq.fifo"
  fifo_queue = true
}

resource "aws_sqs_queue_redrive_policy" "log_redrive" {
  queue_url = aws_sqs_queue.log_queue.id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.log_dlq.arn
    maxReceiveCount     = 5
  })
}

output "sqs_queue_url" {
  value = aws_sqs_queue.log_queue.id
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.log_queue.arn
}