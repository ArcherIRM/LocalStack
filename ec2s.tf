data "aws_ami" "latest_windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-*-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_iam_policy" "archer_ec2_policy" {
  name        = "${var.stack_name}-ec2-policy"
  path        = "/"
  description = "${var.stack_name} EC2 access for SSM and Secrets"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "archer_ec2_role" {
  name = "${var.stack_name}-ec2-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Effect": "Allow",
          "Principal": {
              "Service": "ec2.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
      }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "archer_ec2_policy_attachment" {
  name = "${var.stack_name}-ec2-policy-attachment"
  roles = [
    aws_iam_role.archer_ec2_role.name
  ]
  policy_arn = aws_iam_policy.archer_ec2_policy.arn
}

resource "aws_iam_instance_profile" "archer_ec2_profile" {
  name = "${var.stack_name}-ec2-profile"
  role = aws_iam_role.archer_ec2_role.name
}


resource "tls_private_key" "archer_ec2_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "key_pair" {
  source     = "terraform-aws-modules/key-pair/aws"
  version    = "2.0.2"
  key_name   = "${var.stack_name}-key-pair"
  public_key = tls_private_key.archer_ec2_private_key.public_key_openssh
}

# module "secrets_manager" {
#   source        = "terraform-aws-modules/secrets-manager/aws"
#   version       = "1.1.1"
#   name_prefix   = "${var.stack_name}-private-key-"
#   description   = "(Base64 encoded) private key for RDP-ing into the ${var.stack_name} EC2 instances."
#   secret_string = base64encode(tls_private_key.archer_ec2_private_key.private_key_pem)
# }

resource "aws_instance" "windows_instance_sql_server" {
  ami                    = data.aws_ami.latest_windows.id # AMI ID from data source. Could easily be a supplied custom AMI ID
  get_password_data      = true
  iam_instance_profile   = aws_iam_instance_profile.archer_ec2_profile.name
  instance_type          = "t3.xlarge"
  key_name               = module.key_pair.key_pair_name
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.archer_sql_server.id]

  #   user_data = <<EOF
  # <powershell>

  # Start-Transcript -path "C:\Archer-Instance-Log.txt" -append

  # Write-Host "Configure UAC to allow privilege elevation in remote shells"
  # Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'LocalAccountTokenFilterPolicy' -Value 1 -Force

  # Write-Host "Install Chocolatey"
  # Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

  # Write-Host "Install SQL Server"
  # choco install sql-server-express -y -v
  # Write-Host "SQL Server installed"

  # Stop-Transcript

  # </powershell>
  # EOF

  tags = {
    Name = "${var.stack_name}-Windows-Instance-SQL-Server"
  }
}

resource "aws_instance" "windows_instance_ssms" {
  ami                    = data.aws_ami.latest_windows.id # AMI ID from data source. Could easily be a supplied custom AMI ID
  get_password_data      = true
  iam_instance_profile   = aws_iam_instance_profile.archer_ec2_profile.name
  instance_type          = "t3.xlarge"
  key_name               = module.key_pair.key_pair_name
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.archer_ssms.id]

  user_data = <<EOF
<powershell>

Start-Transcript -path "C:\Archer-Instance-Log.txt" -append

Write-Host "Configure UAC to allow privilege elevation in remote shells"
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'LocalAccountTokenFilterPolicy' -Value 1 -Force

Write-Host "Install Chocolatey"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

Write-Host "Install SQL Server Management Studio"
choco install sql-server-management-studio -y
Write-Host "SSMS installed"

Stop-Transcript

</powershell>
EOF

  tags = {
    Name = "${var.stack_name}-Windows-Instance-SSMS"
  }
}
