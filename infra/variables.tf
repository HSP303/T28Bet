variable "project_name" {
  description = "Nome base usado nos recursos."
  type        = string
  default     = "lab-eks-app"
}

variable "aws_region" {
  description = "Região AWS."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR da VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "availability_zones_count" {
  description = "Quantidade de AZs usadas. Recomendo 2 ou 3 no laboratório."
  type        = number
  default     = 3
}

variable "enable_nat_gateway" {
  description = "Cria NAT Gateway para nodes privados acessarem internet/ECR. Pode gerar custo."
  type        = bool
  default     = true
}

variable "eks_version" {
  description = "Versão do Kubernetes no EKS."
  type        = string
  default     = "1.30"
}

variable "eks_cluster_role_name" {
  description = "Nome do role IAM preexistente usado pelo cluster EKS no Learner Lab."
  type        = string
  default     = "LabEksClusterRole"
}

variable "eks_node_role_name" {
  description = "Nome do role IAM preexistente usado pelo node group EKS no Learner Lab."
  type        = string
  default     = "LabEksNodeRole"
}

variable "node_instance_types" {
  description = "Tipos de instância dos worker nodes."
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_min_size" {
  description = "Mínimo de nodes EC2 no node group."
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "Quantidade desejada de nodes EC2."
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Máximo de nodes EC2."
  type        = number
  default     = 5
}

variable "node_disk_size" {
  description = "Tamanho do disco dos nodes em GB."
  type        = number
  default     = 20
}

variable "redis_node_type" {
  description = "Classe da instância do ElastiCache Redis."
  type        = string
  default     = "cache.t3.micro"
}

variable "enable_metrics_server" {
  description = "Habilita o metrics-server para HPA por CPU. Pode ser desligado para estabilizar o bootstrap."
  type        = bool
  default     = false
}

variable "enable_cloudwatch_observability_addon" {
  description = "Habilita o add-on Amazon CloudWatch Observability no EKS. Pode exigir permissão extra no lab."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags adicionais."
  type        = map(string)
  default     = {}
}

variable "mongodb_uri" {
  description = "URI de conexão com o MongoDB"
  type        = string
  sensitive   = true
}
