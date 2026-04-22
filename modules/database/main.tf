resource "aws_db_subnet_group" "db_group" {
  name       = "db-subnet-group-new"
  subnet_ids = var.db_subnets
}

resource "aws_security_group" "rds_sg" {
  name   = "rds-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_sg_id]
  }
}

resource "aws_db_instance" "postgres" {
  identifier           = "api-database"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  db_name              = var.db_name
  username             = var.db_user
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.db_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  multi_az             = true # <--- RESILIÊNCIA
  skip_final_snapshot  = true
}