# ---------------------------------------------------------------------------
# Public entry point for the commerce API: ALB -> target group -> ECS tasks,
# plus the two security groups that gate the traffic.
#
# Traffic path:
#   internet --:80--> ALB (alb SG) --:8080--> Fargate task (task SG)
#
# VPC + subnets come from the platform-shared workspace via remote state, so
# this workspace never hardcodes network IDs.
# ---------------------------------------------------------------------------

# ----- Security groups -----------------------------------------------------

# Public front door: anyone on the internet may reach the ALB on :80.
resource "aws_security_group" "alb" {
  name        = "commerce-alb-sg"
  description = "Allow inbound HTTP traffic from the internet"
  vpc_id      = data.terraform_remote_state.platform.outputs.vpc_id

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
}

# The container's SG. Inbound 8080 is allowed ONLY from the ALB's SG (note this
# references a security group, not a CIDR) — so the container is never directly
# reachable from the internet, only through the load balancer. Egress is open so
# the task can pull from ECR, read the DB secret from Secrets Manager, and reach
# RDS.
resource "aws_security_group" "task" {
  name        = "commerce-task-sg"
  description = "Allow app port 8080 from the ALB only"
  vpc_id      = data.terraform_remote_state.platform.outputs.vpc_id

  ingress {
    description     = "App port from the ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----- Load balancer -------------------------------------------------------

# Internet-facing ALB. Must live in >=2 public subnets across AZs (the list
# from platform-shared) and wears the alb SG defined above.
resource "aws_lb" "commerce_alb" {
  name               = "commerce-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.terraform_remote_state.platform.outputs.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
}

# Target group the ALB forwards to. target_type = "ip" because Fargate tasks
# register by IP (there is no EC2 instance to register). Port 8080 = the
# container port; the health check hits the app's liveness endpoint, so an
# unhealthy app is pulled out of rotation automatically.
resource "aws_lb_target_group" "commerce_api" {
  name        = "commerce-target-group"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.platform.outputs.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health/status/live"
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# HTTP listener on :80 forwarding to the target group. HTTPS:443 + an ACM cert
# come later, once a final domain is chosen.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.commerce_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.commerce_api.arn
  }
}
