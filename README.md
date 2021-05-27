# cloud-1

📚 school project to discover cloud environments (provisioning / configuration / deployment)

## Overview

This project uses various technologies to deploy a previously realized school project website ([camagru](https://github.com/Alblfbv/camagru)) in kubernetes, both locally and in the cloud, on AWS.

Technologies used

- Vagrant
- Terraform
- Ansible
- Kubernetes (Kubeadm, Flannel, Ingress-nginx, Metallb)
- AWS (Route53, RDS, EC2, ELB, S3, ACM, KMS)

## Provisionning

### local

I wanted to deploy a local k8s cluster that would mimic closely a cloud k8s cluster. \
To achieve that, I chose vagrant to spin up vms, 1 for the master, 2 as nodes (workers)

### cloud

I chose AWS as it's the most used cloud provider as of today. \
I used terraform to provision AWS resources neccessary to deploy a minimal self-managed k8s cluster (2 t2.micro ec2, 1 master, 1 node)

## Configuration and Deployment

I used ansible to configure k8s and deploy my app to local and cloud environments, with two main roles and subroles :

- configuration : k8s cluster creation
- deployment: spin up the k8s resources to make the app run

#### playbook usefull tags

- --skip-tags
  - cloud
  - local
  - first-run
- --tags
  - config
  - deployment
    - db
    - pma
    - dashboard
    - app
