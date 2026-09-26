
variable "region" {
  type    = string
  default = "us-west-2"
}

variable "ami_id" {
  type    = string
  default = "ami-0fc5d935ebf8bc3bc" # Ubuntu 22.04
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "master_count" {
  type    = number
  default = 3
}

variable "worker_count" {
  type    = number
  default = 2
}

variable "root_volume_size" {
  type        = number
  description = "Root volume size in GiB"
  default     = 100
}

variable "root_volume_type" {
  type        = string
  description = "Type of root volume"
  default     = "gp3"
}

variable "ssh_allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "web_allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "security_group_name" {
  type    = string
  default = "k3s-cluster-sg"
}

variable "security_group_description" {
  type    = string
  default = "K3s cluster security group"
}

variable "ssh_public_key_path" {
  type    = string
  default = "/home/ubuntu/.ssh/id_rsa.pub"
}


variable "ssh_private_key_path" {
  type    = string
  default = "/home/ubuntu/.ssh/id_rsa"
}
