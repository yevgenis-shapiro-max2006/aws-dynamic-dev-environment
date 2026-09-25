
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

provider "aws" {
  region = var.region
}

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Subnets in the default VPC (fixed for AWS provider v5+)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Use the first subnet (can be randomized or made smarter)
data "aws_subnet" "default" {
  id = tolist(data.aws_subnets.default.ids)[0]
}

resource "aws_security_group" "k3s_sg" {
  name        = var.security_group_name
  description = var.security_group_description
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "K3s API (6443)"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  ingress {
    description = "K3s HTTS (443)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.https_allowed_cidr]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.security_group_name
  }
}

resource "aws_key_pair" "generated_key" {
  key_name   = "ubuntu"
  public_key = file(var.ssh_public_key_path)
}

resource "aws_instance" "k3s_master" {
  count         = var.master_count
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.generated_key.key_name
  subnet_id     = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.root_volume_size     # e.g., 30 (in GiB)
    volume_type = var.root_volume_type     # e.g., "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "k3s-master-${count.index}"
    Role = "master"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = self.public_ip
  }

  provisioner "file" {
    source      = var.ssh_private_key_path
    destination = "/home/ubuntu/.ssh/id_rsa"
  }

  provisioner "file" {
    source      = "install.sh"
    destination = "/tmp/install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/.ssh/id_rsa",
      "chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa",
      "chmod +x /tmp/install.sh",
      "bash /tmp/install.sh ${count.index} ${self.private_ip} ${var.master_count}"
    ]
  }
}

resource "aws_instance" "k3s_worker" {
  count         = var.worker_count
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.generated_key.key_name
  subnet_id     = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.root_volume_size     # e.g., 30 (in GiB)
    volume_type = var.root_volume_type     # e.g., "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "k3s-worker-${count.index}"
    Role = "worker"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = self.public_ip
  }

  provisioner "file" {
    source      = var.ssh_private_key_path
    destination = "/home/ubuntu/.ssh/id_rsa"
  }

  provisioner "file" {
    source      = "install.sh"
    destination = "/tmp/install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/.ssh/id_rsa",
      "chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa",
      "chmod +x /tmp/install.sh",
      "bash /tmp/install.sh ${count.index} ${aws_instance.k3s_master[0].private_ip} ${var.master_count}"
    ]
  }

  depends_on = [aws_instance.k3s_master]
}


