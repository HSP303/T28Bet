resource "aws_security_group" "redis" {
  name        = "${local.name}-redis-sg"
  description = "Permite acesso ao ElastiCache Redis apenas a partir do EKS"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Redis from EKS cluster security group"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
  }

  egress {
    description = "Saida liberada"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-redis-sg"
  })
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name}-redis-subnet-group"
  subnet_ids = values(aws_subnet.private)[*].id

  tags = merge(local.common_tags, {
    Name = "${local.name}-redis-subnet-group"
  })
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${local.name}-redis"
  description          = "Redis cache para o T28Bet"

  engine             = "redis"
  node_type          = var.redis_node_type
  port               = 6379
  num_cache_clusters = 1

  automatic_failover_enabled = false
  apply_immediately          = true
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]

  at_rest_encryption_enabled = false
  transit_encryption_enabled = false

  tags = merge(local.common_tags, {
    Name = "${local.name}-redis"
  })
}
