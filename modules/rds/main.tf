data "aws_partition" "current" {}

data "aws_iam_policy_document" "key" {
  #checkov:skip=CKV_AWS_111:Standard KMS key policy: the account root delegates to IAM, scoped to this key
  #checkov:skip=CKV_AWS_109:Standard KMS key policy: the account root delegates to IAM, scoped to this key
  #checkov:skip=CKV_AWS_356:In a key policy "*" means "this key"
  statement {
    sid       = "AccountRoot"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${var.account_id}:root"]
    }
  }
}

resource "aws_kms_key" "this" {
  count                   = var.kms_key_arn == null ? 1 : 0
  description             = "RDS ${var.name} storage, backups and master secret"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.key.json
  tags                    = var.tags
}

locals {
  kms_key_arn = var.kms_key_arn == null ? aws_kms_key.this[0].arn : var.kms_key_arn
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-data"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "db" {
  name_prefix = "${var.name}-rds-"
  description = "PostgreSQL from the application tier only"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-rds" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_app" {
  # count, not for_each: the security group IDs are only known after apply, but how many there are is not.
  count                        = length(var.allowed_security_group_ids)
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from the application tier"
  referenced_security_group_id = var.allowed_security_group_ids[count.index]
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name}-pg-"
  family      = "postgres${var.engine_version}"
  tags        = var.tags

  # TLS is mandatory in transit.
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  parameter {
    name  = "log_connections"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "monitoring_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = "${var.name}-rds-enhanced-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-school"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = "school"
  username = "school_admin"
  # RDS creates and rotates the master password in Secrets Manager; it never appears in Terraform code.
  manage_master_user_password   = true
  master_user_secret_kms_key_id = local.kms_key_arn

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = local.kms_key_arn

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  iam_database_authentication_enabled = true
  auto_minor_version_upgrade          = true
  copy_tags_to_snapshot               = true

  backup_retention_period         = var.backup_retention_days
  backup_window                   = "02:00-03:00"
  maintenance_window              = "sun:03:30-sun:04:30"
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = var.skip_final_snapshot ? null : "${var.name}-school-final"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.monitoring.arn
  performance_insights_enabled    = true
  performance_insights_kms_key_id = local.kms_key_arn

  tags = var.tags
}
