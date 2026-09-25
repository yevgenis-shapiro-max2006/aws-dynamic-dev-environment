
###  ---  Default Template  ---  ###
region         = "us-west-2"
ami_id         = "ami-0345dd2cef523536e"
instance_type  = "t3.large"
master_count   = 1
worker_count   = 4
ssh_allowed_cidr = "0.0.0.0/0" # Replace with your IP
security_group_name = "k3s-sg"
security_group_description = "K3s cluster SG"
