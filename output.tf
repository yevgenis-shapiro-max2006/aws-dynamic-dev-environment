
output "k3s_master_ips" {
  description = "Public IPs of all master nodes"
  value       = aws_instance.k3s_master[*].public_ip
}

output "k3s_worker_ips" {
  description = "Public IPs of all worker nodes"
  value       = aws_instance.k3s_worker[*].public_ip
}

output "k3s_master_private_ips" {
  description = "Private IPs of all master nodes"
  value       = aws_instance.k3s_master[*].private_ip
}

output "k3s_worker_private_ips" {
  description = "Private IPs of all worker nodes"
  value       = aws_instance.k3s_worker[*].private_ip
}

