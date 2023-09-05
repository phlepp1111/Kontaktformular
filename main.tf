provider "aws" {
  region = "eu-central-1"
}
#VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
    tags = {
        Name = "main"
    }
}
# Subnet
resource "aws_subnet" "private_subnet_1" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "eu-central-1a"
}
resource  "aws_subnet" "private_subnet_2" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.20.0/24"
    availability_zone = "eu-central-1b"
}
resource  "aws_subnet" "public_subnet_1" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true
    availability_zone = "eu-central-1a"
}
resource  "aws_subnet" "public_subnet_2" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.10.0/24"
    map_public_ip_on_launch = true
    availability_zone = "eu-central-1b"
}
#Internet gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main.id
}
# Öffentliche Routing-Tabelle erstellen und IGW hinzufügen
resource "aws_route_table" "routing_table_oeffentlich" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main_igw.id}"
  }
}
resource "aws_route_table_association" "schrauben-public-rt-regel1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.routing_table_oeffentlich.id
}
resource "aws_route_table_association" "schrauben-public-rt-regel2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.routing_table_oeffentlich.id
}
# Private Routing-Tabelle erstellen
resource "aws_route_table" "routing_table_privat" {
  vpc_id = aws_vpc.main.id
}
# Verknüpfung der privaten Routing-Tabelle mit dem privaten Subnetz
resource "aws_route_table_association" "schrauben-private-rt-regel1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.routing_table_privat.id
}
resource "aws_route_table_association" "schrauben-private-rt-regel2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.routing_table_privat.id
}
# Security group EC2
resource "aws_security_group" "ec2_sg" {
    name   = "ec2_sg"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.1.0/24"]
    }
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.10.0/24"]
    }
     ingress {
        from_port   = 22
        to_port     = 22
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
        from_port   = 3000
        to_port     = 3000
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
# ALB Security Group
resource "aws_security_group" "alb_sg"{
 name = "alb_sg"
 vpc_id = aws_vpc.main.id
 ingress{
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
 }
 ingress {
  from_port   = 3000
  to_port     = 3000
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }
 egress{
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
 }
#   egress{
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["10.0.20.0/24"]
#  }
#  egress{
#     from_port = 3000
#     to_port = 3000
#     protocol = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#  }
}
# target group
resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}
# ALB
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  enable_deletion_protection = false
  enable_cross_zone_load_balancing   = true
  enable_http2                       = true
  idle_timeout                       = 60

  subnets = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}
# ALB Listener
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}
# Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  name                 = "web-asg"
  launch_configuration = aws_launch_configuration.web_lc_1.name
  min_size             = 1
  max_size             = 5
  desired_capacity     = 2
  vpc_zone_identifier  = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  target_group_arns    = [aws_lb_target_group.web_tg.arn]

  tag {
    key                 = "Name"
    value               = "web-asg-instance"
    propagate_at_launch = true
  }
}
# Create the first launch configuration
resource "aws_launch_configuration" "web_lc_1" {
  name_prefix          = "web-lc-1-"
  image_id             = "ami-04e601abe3e1a910f" #ubuntu
  instance_type       = "t2.micro"
  security_groups    = [aws_security_group.ec2_sg.id]
  iam_instance_profile = aws_iam_instance_profile.beschwerdebilder-bucket-iam-profil.id
  associate_public_ip_address = true
  user_data = <<-EOT
              #!/bin/bash
              mkdir /home/ubuntu/server
              cd /home/ubuntu/server
              wget https://ec2-webserver-bucket.s3.eu-central-1.amazonaws.com/index.html
              wget https://ec2-webserver-bucket.s3.eu-central-1.amazonaws.com/server.js
              wget https://ec2-webserver-bucket.s3.eu-central-1.amazonaws.com/package.json
              sudo apt-get update -y
              sudo apt-get install -y nodejs
              sudo apt-get install -y npm
              sudo npm install
              sudo chmod 777 /home/ubuntu/server/server.js
              sudo chmod 777 /home/ubuntu/server/public/index.html
              sudo node ./server.js
              EOT
  lifecycle {
    create_before_destroy = true
  }
}

# Create an Auto Scaling Policy
resource "aws_autoscaling_policy" "scale_up" {
  name               = "scale-up-policy"
  scaling_adjustment = 1
  adjustment_type    = "ChangeInCapacity"
  cooldown           = 30 # Wait time in seconds between scaling actions
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

# CloudWatch Metric Alarm to trigger the scaling policy
resource "aws_cloudwatch_metric_alarm" "scale_up" {
  alarm_name          = "scale-up-on-high-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1" # Modify this value based on when you want to scale up
  alarm_description   = "This metric triggers when there are too many requests on the ALB"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  dimensions = {
    LoadBalancer      = "app/${aws_lb.web_alb.name}/${aws_lb.web_alb.id}"
    AvailabilityZone  = "eu-central-1a"
  }
}
##S3 Bucket
resource "aws_s3_bucket" "beschwerdebilder" {
  bucket = "beschwerdebilder"
}
resource "aws_iam_policy" "beschwerdebilder_bucket_regeln" {
  name        = "beschwerdebilder-iam-bucket-zugriff-regeln"
  path        = "/"
  description = "Allow "

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : ["s3:*"],
        "Resource" : ["*"]
      }
    ]
  })
}

resource "aws_iam_role" "kontakt_ec2_rolle" {
  name = "kontakt_ec2_rolle"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

#Jetzt können wir die Regeln zur Rolle hinzufügen
resource "aws_iam_role_policy_attachment" "beschwerdebilder_bucket_policy_attachment" {
  role       = aws_iam_role.kontakt_ec2_rolle.name
  policy_arn = aws_iam_policy.beschwerdebilder_bucket_regeln.arn
}

#Um eine rolle zu einer EC2 Instanz hinzufügen zu können
#Brauchen wir ein "Instanz-Profil", welches die Rolle beinhaltet
resource "aws_iam_instance_profile" "beschwerdebilder-bucket-iam-profil" {
  name = "beschwerdebilder-bucket-iam-profil"
  role = aws_iam_role.kontakt_ec2_rolle.name
}

#DynamoDB VPC IAM
resource "aws_iam_policy" "beschwerdedaten_ddb_regeln" {
  name        = "beschwerdedaten-iam-ddb-zugriff-regeln"
  path        = "/"
  description = "Allow "

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : ["dynamodb:*"],
        "Resource" : ["*"]
      }
    ]
  })
}
# resource "aws_iam_role" "beschwerdedaten_ddb_rolle" {
#   name = "beschwerdedaten-ddb-iam-rolle"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Sid    = ""
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#       },
#     ]
#   })
# }
resource "aws_iam_role_policy_attachment" "beschwerdedaten_ddb_policy_attachment" {
  role       = aws_iam_role.kontakt_ec2_rolle.name
  policy_arn = aws_iam_policy.beschwerdedaten_ddb_regeln.arn
}
resource "aws_iam_instance_profile" "beschwerdedaten-ddb-iam-profil" {
  name = "beschwerdedaten-ddb-iam-profil"
  role = aws_iam_role.kontakt_ec2_rolle.name
}
#DynamoDB
resource "aws_dynamodb_table" "BeschwerdeDaten" {
  name           = "BeschwerdeDaten"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  range_key = "email"
  server_side_encryption {
    enabled = true
  }
  attribute {
  name = "id"
  type = "N"
  }
  attribute {
    name = "email"
    type = "S"
 }
}
#DDB VPC endpoint
resource "aws_vpc_endpoint" "ddb-vpc-endpoint" {
  vpc_id          = aws_vpc.main.id
  service_name    = "com.amazonaws.eu-central-1.dynamodb"
  #zur privaten routing tabelle hinzufügen
  route_table_ids = ["${aws_route_table.routing_table_privat.id}"]

  tags = {
    Name = "ddb-vpc-endpoint"
  }
}#S3 VPC endpoint
resource "aws_vpc_endpoint" "s3-vpc-endpoint" {
  vpc_id          = aws_vpc.main.id
  service_name    = "com.amazonaws.eu-central-1.s3"
  #zur privaten routing tabelle hinzufügen
  route_table_ids = ["${aws_route_table.routing_table_privat.id}"]

  tags = {
    Name = "s3-vpc-endpoint"
  }
}