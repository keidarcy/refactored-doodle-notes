# terraform state show aws_eip.one
# terraform apply -var-file=variables.tfvars -state=terraform.tfstate -auto-approve
# terraform output -json | jq -r '.public_ip.value'
# terraform refresh
# terraform destory -target aws_instance.web-server-instace
# terraform apply -target aws_instance.web-server-instace -var-file=variables.tfvars -auto-approve
# terraform apply -var "subnet-prefix=10.0.100.0/24"

variable "subnet_prefix" {
  description = "cidr block for the subnet"
  default = "10.0.55.1/24"
  # type = "string"
}

# resource "aws_vpc" "prod-vpc" {
#   cidr_block = "10.0.0.0/16"
#   tags = {
#     Name = "production"
#   }
# }

# resource "aws_subnet" "subnet-1" {
#   vpc_id            = aws_vpc.prod-vpc.id
#   cidr_block        = var.subnet_prefix[0].cidr_block
#   availability_zone = "us-east-1a"

#   tags = {
#     Name = var.subnet_prefix[0].name
#   }
# }

# resource "aws_subnet" "subnet-2" {
#   vpc_id            = aws_vpc.prod-vpc.id
#   cidr_block        = var.subnet_prefix[1].cidr_block
#   availability_zone = "us-east-1a"

#   tags = {
#     Name = var.subnet_prefix[1].name
#   }
# }

provider "aws" {
	region = "ap-northeast-1"
}

# 1. Create a VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    name = "production"
  } 
}

# 2. Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.prod-vpc.id}"
}

# 3. Create a route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = "${aws_vpc.prod-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    name = "prod-route-table"
  }
}


# 4. Create a subnet
resource "aws_subnet" "subnet-1" {
  vpc_id = "${aws_vpc.prod-vpc.id}"
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "prod-subnet-1"
  }
}

# 5. Associate the route table with the subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 6. Create a web server security group
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "web-server-nic" {
  subnet_id = aws_subnet.subnet-1.id
  private_ips = ["10.0.1.50"]
  security_groups = [ "aws_security_group.allow_web.id" ]
}

# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

# 9. Create Ubuntu server and install/enable apache2

resource "aws_instance" "web-server-instance" {
  ami               = "ami-085925f297f89fce1"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "main-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF
  tags = {
    Name = "web-server"
  }
}

# output "server_private_ip" {
#   value = aws_instance.web-server-instance.private_ip

# }

# output "server_id" {
#   value = aws_instance.web-server-instance.id
# }


# resource "<provider>_<resource_type>" "name" {
#     config options.....
#     key = "value"
#     key2 = "another value"
# }




