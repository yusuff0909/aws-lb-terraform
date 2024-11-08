# Create a security group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Application load balancer security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = "0"
    protocol    = "-1"
    to_port     = "0"
  }

  tags = {
    Name = "alb-security-group"
  }
}

# Create a target group
resource "aws_lb_target_group" "alb-target-group" {
  name     = "application-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 10
    matcher             = 200
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 6
    unhealthy_threshold = 3
  }
}

# Attach the target group to the AWS instances
resource "aws_lb_target_group_attachment" "attach-app" {
  count            = length(aws_instance.web-server)
  target_group_arn = aws_lb_target_group.alb-target-group.arn
  target_id        = element(aws_instance.web-server.*.id, count.index)
  port             = 80
}

# Create a listener for load balancer
resource "aws_lb_listener" "alb-http-listener" {
    load_balancer_arn = aws_lb.application-lb.arn
    port              = "80"
    protocol          = "HTTP"
  
    default_action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.alb-target-group.arn
    }
  }

# Create the load balancer
resource "aws_lb" "application-lb" {
  name               = "application-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for subnet in aws_subnet.private : subnet.id]

  enable_deletion_protection = false

  tags = {
    Environment = "application-lb"
    Name        = "Application-lb"
    
  }
}
