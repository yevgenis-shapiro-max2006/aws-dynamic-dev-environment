<img width="1544" height="1018" alt="image" src="https://github.com/user-attachments/assets/cfd04231-2738-420e-814e-c2e4e06c9d53" />



## AWS ☸️ | K3S Dynamic Environment
K3s as a lightweight and certified Kubernetes distribution developed by Rancher Labs (now part of SUSE). Designed to streamline deployments in edge computing, IoT, and local development scenarios, K3s provides a simplified alternative to traditional Kubernetes. By consolidating essential components into a single, efficient binary, K3s aims to maintain core Kubernetes functionalities while reducing the overhead typically associated with deployment and management.


🎯  Installation and Integration
```
✅ Launch EC2 Instances
✅ Install K3S Binary ( Kubernetes )
✅ Prepare Cluster Configuration
✅ Deploy ApplicationSet via Terraform Provider
```

🚀 
```
terraform init
terraform validate
terraform plan -var-file="template.tfvars"
terraform apply -var-file="template.tfvars" -auto-approve
```

🧩 Config 

```
scp -i ~/.ssh/<your pem file> <your pem file> ec2-user@<terraform instance public ip>:/home/ec2-user
chmod 400 <your pem file>
```

