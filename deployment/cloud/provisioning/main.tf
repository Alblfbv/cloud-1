terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.39"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}

resource "aws_vpc" "k8s-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name                               = "k8s"
    "kubernetes.io/cluster/kubernetes" = "owned"
    project                            = "cloud-1"
  }
}


resource "aws_subnet" "k8s-subnet1" {
  vpc_id            = aws_vpc.k8s-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-3a"

  tags = {
    Name                               = "k8s-subnet1"
    "kubernetes.io/cluster/kubernetes" = "owned"
    project                            = "cloud-1"
  }
}

resource "aws_subnet" "k8s-subnet2" {
  vpc_id            = aws_vpc.k8s-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-3b"

  tags = {
    Name                               = "k8s-subnet2"
    "kubernetes.io/cluster/kubernetes" = "owned"
    project                            = "cloud-1"
  }
}

resource "aws_db_subnet_group" "database" {
  name       = "database-subnet"
  subnet_ids = [aws_subnet.k8s-subnet1.id, aws_subnet.k8s-subnet2.id]

  tags = {
    project = "cloud-1"
  }
}

resource "aws_internet_gateway" "k8s-gw" {
  vpc_id = aws_vpc.k8s-vpc.id

  tags = {
    Name                               = "k8s"
    "kubernetes.io/cluster/kubernetes" = "owned"
    project                            = "cloud-1"
  }
}

resource "aws_route_table" "k8s-routing" {
  vpc_id = aws_vpc.k8s-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s-gw.id
  }

  tags = {
    Name                               = "k8s"
    "kubernetes.io/cluster/kubernetes" = "owned"
    project                            = "cloud-1"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.k8s-subnet1.id
  route_table_id = aws_route_table.k8s-routing.id
}

resource "aws_security_group" "allow_db_connection" {
  name        = "allow_db_connection"
  description = "Allow HTTP/HTTPS/SSH inbound traffic"
  vpc_id      = aws_vpc.k8s-vpc.id

  ingress {
    description = "DB connection"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                               = "allow_web_ssh"
    "kubernetes.io/cluster/kubernetes" = "owned"
    project                            = "cloud-1"
  }
}

resource "aws_security_group" "allow_web_ssh" {
  name        = "allow_web_ssh"
  description = "Allow HTTP/HTTPS/SSH inbound traffic"
  vpc_id      = aws_vpc.k8s-vpc.id

  ingress {
    description = "Kube-API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    description = "Etcd-API"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    description = "Kubelet-API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    description = "Kube-scheduler"
    from_port   = 10251
    to_port     = 10251
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    description = "Kube-controller-manager"
    from_port   = 10252
    to_port     = 10252
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    description = "NLB"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                               = "allow_web_ssh"
    "kubernetes.io/cluster/kubernetes" = "owned"
    project                            = "cloud-1"
  }
}

resource "aws_network_interface" "master-eni" {
  subnet_id       = aws_subnet.k8s-subnet1.id
  private_ips     = ["10.0.1.100"]
  security_groups = [aws_security_group.allow_web_ssh.id]

  tags = {
    project = "cloud-1"
  }
}

resource "aws_network_interface" "worker-1-eni" {
  subnet_id       = aws_subnet.k8s-subnet1.id
  private_ips     = ["10.0.1.110"]
  security_groups = [aws_security_group.allow_web_ssh.id]

  tags = {
    project = "cloud-1"
  }
}

resource "aws_eip" "master-eip" {
  vpc                       = true
  network_interface         = aws_network_interface.master-eni.id
  associate_with_private_ip = "10.0.1.100"
  depends_on = [
    aws_internet_gateway.k8s-gw
  ]

  tags = {
    project = "cloud-1"
  }
}

resource "aws_eip" "worker-1-eip" {
  vpc                       = true
  network_interface         = aws_network_interface.worker-1-eni.id
  associate_with_private_ip = "10.0.1.110"
  depends_on = [
    aws_internet_gateway.k8s-gw
  ]

  tags = {
    project = "cloud-1"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "ansible-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC/3pxOFSZJSTieCcQfUJCHtJcwRyNMpzsPlnHmsJw63psufZNV5O5+b46Fvo1Eccb6vPpmzV4wg7aeyE062DjCHbpiL8XA0JFAgYUfUSQzLi6xkAXeXa1aISiadykE3fdc5V/zk5XKDqBbK657e131HEwEUDkZI9gD5tyli1MUG81VnVHDbCYiO2EbVSgHmIIlKw295yhbTLC3MQRletmTrQPAhjTF8xhg/bUQplLXGvaz6KpznAk8VM7Tf1eRd0gIPPWgcHLHZodyAXuDKAKZa5uFv/YNvVPrJ/M48ULMfDk/mlpRroww5JZvAvjojMfCOmed8YmZ6aXeo39rpv+eKUSKaybwfFRYq17EZxjw0uNM9T3sNT+i09Dx2NKEWR+FS3FsCNQkXjaNUpFG2nQmpqd4gcrxAJLeZKEo2Y8SFAON11BDJddXNvTgRcRsumlZg5seOYYxb+euz5YI9B2ztxALmykw+0q7VYqBn8T4DNbHoAjd9PCd+1L6KNWu3GM="

  tags = {
    project = "cloud-1"
  }

}

resource "aws_iam_role" "master-role" {
  name = "master-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })

  tags = {
    project = "cloud-1"
  }
}

resource "aws_iam_role" "worker-role" {
  name = "worker-role"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "ec2.amazonaws.com"
          },
          "Effect" : "Allow",
          "Sid" : ""
        }
      ]
  })

  tags = {
    project = "cloud-1"
  }
}


resource "aws_iam_policy" "worker-policy" {
  name = "worker-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeInstances",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeRegions",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:BatchGetImage"
        ],
        "Resource" : "*"
      }
    ]
  })

  tags = {
    project = "cloud-1"
  }
}

resource "aws_iam_policy" "master-policy" {
  name = "master-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:ModifyInstanceAttribute",
          "ec2:ModifyVolume",
          "ec2:AttachVolume",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteVolume",
          "ec2:DetachVolume",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DescribeVpcs",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:AttachLoadBalancerToSubnets",
          "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateLoadBalancerPolicy",
          "elasticloadbalancing:CreateLoadBalancerListeners",
          "elasticloadbalancing:ConfigureHealthCheck",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancerListeners",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DetachLoadBalancerFromSubnets",
          "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
          "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeLoadBalancerPolicies",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
          "iam:CreateServiceLinkedRole",
          "kms:DescribeKey"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })

  tags = {
    project = "cloud-1"
  }
}

resource "aws_iam_policy_attachment" "master-role-policy-attachment" {
  name       = "master-role-policy-attachment"
  roles      = [aws_iam_role.master-role.name]
  policy_arn = aws_iam_policy.master-policy.arn
}

resource "aws_iam_policy_attachment" "worker-role-policy-attachment" {
  name       = "worker-role-policy-attachment"
  roles      = [aws_iam_role.worker-role.name]
  policy_arn = aws_iam_policy.worker-policy.arn
}

resource "aws_iam_instance_profile" "master-profile" {
  name = "master-profile"
  role = aws_iam_role.master-role.name

  tags = {
    project = "cloud-1"
  }
}

resource "aws_iam_instance_profile" "worker-profile" {
  name = "worker-profile"
  role = aws_iam_role.worker-role.name

  tags = {
    project = "cloud-1"
  }
}

resource "aws_instance" "kubernetes_master" {
  ami                  = "ami-0f7cd40eac2214b37"
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.master-profile.name
  availability_zone    = "eu-west-3a"
  key_name             = "ansible-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.master-eni.id
  }

  tags = {
    Name                               = "master"
    group                              = "masters"
    project                            = "cloud-1"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

resource "aws_instance" "kubernetes_worker-1" {
  ami                  = "ami-0f7cd40eac2214b37"
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.worker-profile.name
  availability_zone    = "eu-west-3a"
  key_name             = "ansible-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.worker-1-eni.id
  }

  tags = {
    Name                               = "worker-1"
    group                              = "workers"
    project                            = "cloud-1"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

resource "aws_db_instance" "cloud1-db" {
  allocated_storage    = 5
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  username             = "***REMOVED***"
  password             = "***REMOVED***"
  db_subnet_group_name = aws_db_subnet_group.database.name
  vpc_security_group_ids = aws_security_group.allow_db_connection.id
  skip_final_snapshot  = true
  
  tags = {
    Name                               = "cloud1-db"
    "kubernetes.io/cluster/kubernetes" = "owned"
    project                            = "cloud-1"
  }
}

resource "aws_s3_bucket" "cloud1-bucket" {
  bucket = "cloud1-bucket"

  tags = {
    Name                               = "cloud1-bucket"
    "kubernetes.io/cluster/kubernetes" = "owned"
    project                            = "cloud-1"
  }
}