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

resource "aws_instance" "windows_instance_sql_server" {
  ami                    = data.aws_ami.latest_windows.id # AMI ID from data source. Could easily be a supplied custom AMI ID
  iam_instance_profile   = aws_iam_instance_profile.archer_ec2_profile.name
  instance_type          = "t3.xlarge"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.archer_sql_server.id]

  user_data = <<EOF
<powershell>

Start-Transcript -path "C:\Archer-Instance-Log.txt" -append

Write-Host "Configure UAC to allow privilege elevation in remote shells"
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'LocalAccountTokenFilterPolicy' -Value 1 -Force

Write-Host "Install Chocolatey"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

Write-Host "Install SQL Server"
choco install sql-server-express -y -no-progress
Write-Host "SQL Server installed"
# choco install sql-server-2022-cumulative-update -y --no-progress
# Write-Host "Cumulative Update installed"

# Start SQL Server service
# Start-Service -Name "MSSQL`$SQLEXPRESS"

# Enable SQL Server authentication
# sqlcmd -S localhost -U SA -P "your_sql_password" -Q "ALTER LOGIN SA ENABLE;"

# Allow remote connections to SQL Server
# Import-Module SQLPS -DisableNameChecking
# Invoke-Sqlcmd -Query "EXEC sp_configure 'remote access', 1; RECONFIGURE;"

# Example: Enable WinRM
# Enable-PSRemoting -Force

Stop-Transcript

</powershell>
EOF

  tags = {
    Name = "${var.stack_name}-Windows-Instance-SQL-Server"
  }
}

resource "aws_instance" "windows_instance_ssms" {
  ami                    = data.aws_ami.latest_windows.id # AMI ID from data source. Could easily be a supplied custom AMI ID
  iam_instance_profile   = aws_iam_instance_profile.archer_ec2_profile.name
  instance_type          = "t3.xlarge"
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
choco install sql-server-management-studio -y --no-progress
Write-Host "SSMS installed"

Stop-Transcript

</powershell>
EOF

  tags = {
    Name = "${var.stack_name}-Windows-Instance-SSMS"
  }
}
