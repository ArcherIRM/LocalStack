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

  user_data = <<EOF
<powershell>

Start-Transcript -path "C:\Archer-Instance-Log.txt" -append

Write-Host "Configure UAC to allow privilege elevation in remote shells"
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'LocalAccountTokenFilterPolicy' -Value 1 -Force

Write-Host "Install Chocolatey"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

Write-Host "Install SQL Server"
choco install sql-server-2022 -y -v
Write-Host "SQL Server installed"

Write-Host "Setting SQL Server Browser service to Automatic and starting the service..."
Set-Service 'SQLBrowser' -StartupType Automatic
Start-Service 'SQLBrowser'

Write-Host "Enabling TCP/IP protocol for SQL Server..."
$sqlServerConfigManager = Get-WmiObject -Namespace "root\Microsoft\SqlServer\ComputerManagement16" -Class "ServerNetworkProtocol"
$tcpIp = $sqlServerConfigManager | Where-Object { $_.InstanceName -eq 'MSSQLSERVER' -and $_.ProtocolName -eq 'Tcp' }
$tcpIp.SetEnable()

Write-Host "Setting the TCP Port for IPAll to 1433..."
$regPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\SuperSocketNetLib\Tcp\IPAll"
Set-ItemProperty -Path $regPath -Name TcpPort -Value "1433"
Set-ItemProperty -Path $regPath -Name TcpDynamicPorts -Value ""

Write-Host "Creating a firewall rule for TCP port 1433..."
New-NetFirewallRule -DisplayName "SQL Server Remote Access" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow

Write-Host "SQL Server Express should now accept remote connections."

Restart-Service 'MSSQLSERVER'
Restart-Service 'SQLBrowser'

Write-Host "Installing the SqlServer module..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri https://github.com/PowerShell/PowerShellGet/archive/master.zip -OutFile c:\psget.zip
Expand-Archive c:\psget.zip -DestinationPath C:\psget
Set-Location c:\psget\PowerShellGet-master\src
Import-Module PowerShellGet -Force
Install-PackageProvider NuGet -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name SqlServer -Force -AllowClobber
Import-Module SqlServer

Write-Host "Defining the SQL Server login"
$Username = "localstack"
$Password = "${var.sa_password}"

$SecPass = ConvertTo-SecureString -String $Password -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SecPass

# Set-Location SQLSERVER:\SQL\localhost
# Get-ChildItem

# Write-Host "Add the SQL Server login to the SQL Server instance"
# Add-SqlLogin -ServerInstance MSSQLSERVER -LoginName $Username -LoginType SqlLogin -DefaultDatabase tempdb -Enable -GrantConnectSql -LoginPSCredential $Credential

# Add-SqlLogin : Failed to connect to server MSSQLSERVER.
# At
# C:\Windows\system32\config\systemprofile\AppData\Local\Temp\Amazon\EC2-Windows\Launch\InvokeUserData\UserScript.ps1:59
# char:1
# + Add-SqlLogin -ServerInstance MSSQLSERVER -LoginName $Username -LoginT ...
# + ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#     + CategoryInfo          : ObjectNotFound: (System.String[]:String[]) [Add-SqlLogin], ConnectionFailureException
#     + FullyQualifiedErrorId : ConnectionToServerFailed,Microsoft.SqlServer.Management.PowerShell.Security.AddSqlLogin

Stop-Transcript

</powershell>
EOF

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
