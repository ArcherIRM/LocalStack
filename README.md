# LocalStack

A repository for code sharing with LocalStack. This repository contains no information proprietary to Archer; it is a project that partially mocks infrastructure for analysis purposes.

## Terraform Deployment: Windows Server with SQL Server

This Terraform script deploys a Windows Server EC2 instance in a new VPC, private subnet, and NAT gateway on AWS. It uses Chocolatey to install SQL Server during instance launch.

### Prerequisites

- Terraform installed locally
- AWS credentials configured

### Usage

#### Deployment

1. Clone the repository:

```bash
git clone 
```

2. Navigate to the project directory:

```bash
cd localstack
```

3. Update the variables.tf file with your desired values.

4. Run the following commands:

```bash
terraform init
terraform plan # optional
terraform apply
```

Follow the on-screen prompts to confirm the deployment.

#### Connecting to the Database

- Retrieve the private key for the EC2 instances: `jq -r '.outputs.ec2_private_key.value | gsub("\\n"; "\n")' terraform.tfstate` > archer-ec2-key.pem
- Get the EC2 password: `aws ec2 get-password-data --instance-id $(aws ec2 describe-instances --filters "Name=tag:Name,Values=Archer-Windows-Instance-SSMS" --query "Reservations[*].Instances[*].[InstanceId]" --no-cli-pager --output text) --priv-launch-key archer-ec2-key.pem --query 'PasswordData' --no-cli-pager --output text`
- SSM to SSMS: `aws ssm start-session --target $(aws ec2 describe-instances --filters "Name=tag:Name,Values=Archer-Windows-Instance-SSMS" --query "Reservations[*].Instances[*].[InstanceId]" --no-cli-pager --output text) --document-name AWS-StartPortForwardingSession --parameters "localPortNumber=8765,portNumber=3389" --region us-west-2`

### Resources

| Resource Type                                          | Description                                     |
|--------------------------------------------------------|-------------------------------------------------|
| aws_vpc.vpc                                           | AWS Virtual Private Cloud (VPC)                 |
| aws_subnet.private_subnet                              | Private subnet within the VPC                   |
| aws_internet_gateway.igw                               | Internet Gateway for NAT Gateway                |
| aws_nat_gateway.nat_gateway                            | NAT Gateway for internet access                 |
| aws_route_table.private_subnet_route_table             | Route table for the private subnet              |
| aws_route_table_association.private_subnet_association | Association of private subnet with route table  |
| aws_instance.windows_instance                          | EC2 instance with Windows Server and SQL Server |

### Customization

Adjust variables in variables.tf for customization.
Modify the user data block in main.tf for additional configurations.

Notes

The SQL Server is installed using Chocolatey during instance launch.
Ensure security best practices are followed, especially when allowing remote connections to SQL Server.
