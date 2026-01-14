# Infrastructure Code - Project Matrix

A Terraform infrastructure-as-code project that provisions AWS resources including VPC, EC2 instances, and S3 buckets.

## Overview

This project uses Terraform to automate the deployment of a complete AWS infrastructure setup with:
- **VPC** with configurable public and private subnets
- **EC2 Instances** for application servers
- **S3 Bucket** for object storage
- **Security Groups** and networking configuration

## Prerequisites

- Terraform >= 1.14.0
- AWS CLI configured with appropriate credentials
- The following Terraform providers:
  - AWS ~> 6.28
  - Random ~> 3.7
  - Time ~> 0.13.0

## Project Structure

aws/
├── main.tf # Main configuration and module definitions
├── variables.tf # Input variables
├── output.tf # Output values
├── terraform.tf # Terraform configuration and required providers
├── terraform.tfvars # Variable values (customize for your environment)
└── modules/
├── ec2-instance/ # EC2 instance module
├── s3-bucket/ # S3 bucket module
└── vpc/ # VPC module (via external registry)

## Input Variables

### Core Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `region` | string | `us-east-1` | AWS Region |
| `vpc_cidr_block` | string | `10.0.0.0/16` | VPC CIDR block |
| `enable_vpn_gateway` | bool | `true` | Enable VPN gateway for the VPC |
| `secret_key` | string | — | Secret key for the hello module (required, sensitive) |

### Subnet Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `public_subnet_count` | number | `2` | Number of public subnets |
| `private_subnet_count` | number | `2` | Number of private subnets |
| `public_subnet_cidr_blocks` | list(string) | `10.0.1.0/24` - `10.0.8.0/24` | Available CIDR blocks for public subnets |
| `private_subnet_cidr_blocks` | list(string) | `10.0.101.0/24` - `10.0.108.0/24` | Available CIDR blocks for private subnets |

### EC2 Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `instance_count` | number | `2` | Number of EC2 instances to provision |

### Tagging

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `resource_tags` | map(string) | `{"project": "project-matrix", "environment": "dev"}` | Tags for all resources |

## Outputs

| Output | Description |
|--------|-------------|
| `s3_bucket_name` | The name of the provisioned S3 bucket |
| `app_server_count` | Count of app servers provisioned |
| `instance_hostname` | The private DNS name of the web server instance |

## Configuration

### Terraform Cloud

This project is configured to use Terraform Cloud:
- **Organization**: akhakpouri
- **Workspace**: learn-terraform-aws

To use Terraform Cloud, ensure you have authentication configured:
```sh
terraform login
```
## Usage
Initialize Terraform
```sh
cd aws
terraform init
```
Plan & apply infrastructure
```sh
terraform plan
terraform apply
```