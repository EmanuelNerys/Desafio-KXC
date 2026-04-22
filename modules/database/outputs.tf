output "db_instance_address" {
  description = "O endereço do banco de dados para a API se conectar"
  value       = aws_db_instance.postgres.address 
}