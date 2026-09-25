
# ============================================================
# K3s Master Public IPs
# ============================================================

output "k3s_master_ips" {
  description = "Public IPs of all master nodes"
  value       = aws_instance.k3s_master[*].public_ip
}

# ============================================================
# K3s Worker Public IPs
# ============================================================

output "k3s_worker_ips" {
  description = "Public IPs of all worker nodes"
  value       = aws_instance.k3s_worker[*].public_ip
}

# ============================================================
# K3s Master Private IPs
# ============================================================

output "k3s_master_private_ips" {
  description = "Private IPs of all master nodes"
  value       = aws_instance.k3s_master[*].private_ip
}

# ============================================================
# K3s Worker Private IPs
# ============================================================

output "k3s_worker_private_ips" {
  description = "Private IPs of all worker nodes"
  value       = aws_instance.k3s_worker[*].private_ip
}

# ============================================================
# VPC
# ============================================================

output "k3s_vpc_id" {
  description = "ID of the K3s VPC"
  value       = aws_vpc.k3s.id
}

output "k3s_vpc_cidr" {
  description = "CIDR block of the K3s VPC"
  value       = aws_vpc.k3s.cidr_block
}

# ============================================================
# Subnets
# ============================================================

output "k3s_subnet_ids" {
  description = "IDs of the K3s public subnets"
  value       = aws_subnet.k3s[*].id
}

output "k3s_availability_zones" {
  description = "Availability zones used by the K3s subnets"
  value       = aws_subnet.k3s[*].availability_zone
}

# ============================================================
# Security Group
# ============================================================

output "k3s_security_group_id" {
  description = "Security group ID for the K3s cluster"
  value       = aws_security_group.k3s_sg.id
}

# ============================================================
# K3s API
# ============================================================

output "k3s_api_private_endpoint" {
  description = "Private K3s API endpoint"
  value       = "https://${aws_instance.k3s_master[0].private_ip}:6443"
}

# ============================================================
# Master SSH
# ============================================================

output "k3s_master_ssh_command" {
  description = "SSH command for the first K3s master"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_instance.k3s_master[0].public_ip}"
}
