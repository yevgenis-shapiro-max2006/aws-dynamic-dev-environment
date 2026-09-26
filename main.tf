
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

# ============================================================
# Availability Zones
# ============================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================
# K3s VPC
# ============================================================

resource "aws_vpc" "k3s" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "k3s-vpc"
  }
}

# ============================================================
# Internet Gateway
# ============================================================

resource "aws_internet_gateway" "k3s" {
  vpc_id = aws_vpc.k3s.id

  tags = {
    Name = "k3s-igw"
  }
}

# ============================================================
# Public Subnets
# ============================================================

resource "aws_subnet" "k3s" {
  count = 3

  vpc_id = aws_vpc.k3s.id

  cidr_block = "10.0.${count.index + 1}.0/24"

  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "k3s-public-${count.index + 1}"
    Role = "k3s"
  }
}

# ============================================================
# Public Route Table
# ============================================================

resource "aws_route_table" "k3s_public" {
  vpc_id = aws_vpc.k3s.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k3s.id
  }

  tags = {
    Name = "k3s-public-rt"
  }
}

# ============================================================
# Route Table Associations
# ============================================================

resource "aws_route_table_association" "k3s_public" {
  count = 3

  subnet_id      = aws_subnet.k3s[count.index].id
  route_table_id = aws_route_table.k3s_public.id
}

# ============================================================
# Security Group
# ============================================================

resource "aws_security_group" "k3s_sg" {
  name        = var.security_group_name
  description = var.security_group_description
  vpc_id      = aws_vpc.k3s.id

  # ----------------------------------------------------------
  # SSH
  # ----------------------------------------------------------

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = [
      var.ssh_allowed_cidr
    ]
  }

  # ----------------------------------------------------------
  # K3s API
  # ----------------------------------------------------------

  ingress {
    description = "K3s API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"

    cidr_blocks = [
      aws_vpc.k3s.cidr_block
    ]
  }

  # ----------------------------------------------------------
  # HTTP
  # ----------------------------------------------------------

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    cidr_blocks = [
      var.web_allowed_cidr
    ]
  }

  # ----------------------------------------------------------
  # HTTPS
  # ----------------------------------------------------------

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"

    cidr_blocks = [
      var.web_allowed_cidr
    ]
  }

  # ----------------------------------------------------------
  # K3s internal traffic
  #
  # Includes:
  # - Flannel
  # - etcd
  # - K3s server communication
  # - kubelet
  # - pod networking
  # ----------------------------------------------------------

  ingress {
    description = "K3s internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = [
      aws_vpc.k3s.cidr_block
    ]
  }

  # ----------------------------------------------------------
  # Outbound
  # ----------------------------------------------------------

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = var.security_group_name
  }
}

# ============================================================
# SSH Key
# ============================================================

resource "aws_key_pair" "generated_key" {
  key_name   = "ubuntu"
  public_key = file(var.ssh_public_key_path)
}

# ============================================================
# ============================================================
# K3s Primary Master
# ============================================================

resource "aws_instance" "k3s_master_primary" {
  count = var.master_count > 0 ? 1 : 0

  ami           = var.ami_id
  instance_type = var.instance_type

  key_name = aws_key_pair.generated_key.key_name

  subnet_id = aws_subnet.k3s[0].id

  vpc_security_group_ids = [
    aws_security_group.k3s_sg.id
  ]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
  }

  tags = {
    Name = "k3s-master-0"
    Role = "master"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = self.public_ip
    timeout     = "5m"
  }

  provisioner "file" {
    source      = var.ssh_private_key_path
    destination = "/home/ubuntu/.ssh/id_rsa"
  }

  provisioner "file" {
    source      = "./modules/k3s/install.sh"
    destination = "/tmp/install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/.ssh/id_rsa",
      "chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa",
      "chmod +x /tmp/install.sh",

      "echo '[+] Starting K3s primary master bootstrap...'",
      "bash /tmp/install.sh 0 ${self.private_ip} ${var.master_count}"
    ]
  }
}

# ============================================================
# K3s Additional Masters
# ============================================================

resource "aws_instance" "k3s_master_additional" {
  count = var.master_count > 1 ? var.master_count - 1 : 0

  ami           = var.ami_id
  instance_type = var.instance_type

  key_name = aws_key_pair.generated_key.key_name

  subnet_id = aws_subnet.k3s[
    (count.index + 1) % 3
  ].id

  vpc_security_group_ids = [
    aws_security_group.k3s_sg.id
  ]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
  }

  tags = {
    Name = "k3s-master-${count.index + 1}"
    Role = "master"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = self.public_ip
    timeout     = "5m"
  }

  provisioner "file" {
    source      = var.ssh_private_key_path
    destination = "/home/ubuntu/.ssh/id_rsa"
  }

  provisioner "file" {
    source      = "./modules/k3s/install.sh"
    destination = "/tmp/install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/.ssh/id_rsa",
      "chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa",
      "chmod +x /tmp/install.sh",

      "echo '[+] Waiting for primary K3s API on ${aws_instance.k3s_master_primary[0].private_ip}:6443...'",
      "for i in $(seq 1 60); do timeout 2 bash -c '</dev/tcp/${aws_instance.k3s_master_primary[0].private_ip}/6443' 2>/dev/null && break; echo '[+] Waiting for K3s API...'; sleep 5; done",
      "timeout 2 bash -c '</dev/tcp/${aws_instance.k3s_master_primary[0].private_ip}/6443' 2>/dev/null || { echo '[-] K3s API did not become reachable'; exit 1; }",
      "echo '[+] Starting K3s additional master bootstrap...'",
      "bash /tmp/install.sh ${count.index + 1} ${aws_instance.k3s_master_primary[0].private_ip} ${var.master_count}"
    ]
  }

  # The primary master must complete its Terraform provisioners before
  # additional masters are created and bootstrapped.
  depends_on = [
    aws_instance.k3s_master_primary
  ]
}

# ============================================================
# Preserve existing master instances during resource split
# ============================================================

moved {
  from = aws_instance.k3s_master[0]
  to   = aws_instance.k3s_master_primary[0]
}

moved {
  from = aws_instance.k3s_master[1]
  to   = aws_instance.k3s_master_additional[0]
}

moved {
  from = aws_instance.k3s_master[2]
  to   = aws_instance.k3s_master_additional[1]
}

# ============================================================
# K3s Workers
# ============================================================

resource "aws_instance" "k3s_worker" {
  count = var.worker_count

  ami           = var.ami_id
  instance_type = var.instance_type

  key_name = aws_key_pair.generated_key.key_name

  subnet_id = aws_subnet.k3s[
    (var.master_count + count.index) % 3
  ].id

  vpc_security_group_ids = [
    aws_security_group.k3s_sg.id
  ]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
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
    timeout     = "5m"
  }

  provisioner "file" {
    source      = var.ssh_private_key_path
    destination = "/home/ubuntu/.ssh/id_rsa"
  }

  provisioner "file" {
    source      = "./modules/k3s/install.sh"
    destination = "/tmp/install.sh"
  }

  provisioner "remote-exec" {
  inline = [
    "chmod 600 /home/ubuntu/.ssh/id_rsa",
    "chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa",
    "chmod +x /tmp/install.sh",

    "echo '[+] Waiting for primary K3s API on ${aws_instance.k3s_master_primary[0].private_ip}:6443...'",
    "for i in $(seq 1 60); do timeout 2 bash -c '</dev/tcp/${aws_instance.k3s_master_primary[0].private_ip}/6443' 2>/dev/null && break; echo '[+] Waiting for K3s API...'; sleep 5; done",
    "timeout 2 bash -c '</dev/tcp/${aws_instance.k3s_master_primary[0].private_ip}/6443' 2>/dev/null || { echo '[-] K3s API did not become reachable'; exit 1; }",
    "echo '[+] Starting K3s worker bootstrap...'",
    "bash /tmp/install.sh ${var.master_count + count.index} ${aws_instance.k3s_master_primary[0].private_ip} ${var.master_count}"
  ]
}


  # Workers start only after the primary and all additional masters
  # have completed their Terraform provisioners.
  depends_on = [
    aws_instance.k3s_master_primary,
    aws_instance.k3s_master_additional
  ]

}

