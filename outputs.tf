output "ec2_private_key" {
  value     = tls_private_key.archer_ec2_private_key.private_key_pem
  sensitive = true
}

# output "ec2_sql_server_instance_id" {
#   value = aws_instance.windows_instance_sql_server.id
# }

# output "ec2_sql_server_name" {
#   value = aws_instance.windows_instance_sql_server.tags.Name
# }

# output "ec2_sql_server_admin_user_password" {
#   value = aws_instance.windows_instance_sql_server.password_data
# }

# output "ec2_sql_server_private_hostname" {
#   value = aws_instance.windows_instance_sql_server.private_dns
# }

output "ec2_sql_server_private_ip" {
  value = aws_instance.windows_instance_sql_server.private_ip
}

# output "ec2_ssms_instance_id" {
#   value = aws_instance.windows_instance_ssms.id
# }

# output "ec2_ssms_name" {
#   value = aws_instance.windows_instance_ssms.tags.Name
# }

# output "ec2_ssme_admin_user_password" {
#   value = aws_instance.windows_instance_ssms.password_data
# }

# output "ec2_ssms_private_hostname" {
#   value = aws_instance.windows_instance_ssms.private_dns
# }

# output "ec2_ssms_private_ip" {
#   value = aws_instance.windows_instance_ssms.private_ip
# }

output "region" {
  value = var.region
}

output "stack_resource_tag" {
  value = local.stack_tag

}

# output "vpc_id" {
#   value = aws_vpc.vpc.id
# }
