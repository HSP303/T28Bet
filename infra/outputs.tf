output "aws_region" {
  value = var.aws_region
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = values(aws_subnet.public)[*].id
}

output "private_subnet_ids" {
  value = values(aws_subnet.private)[*].id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.this.name
}

output "eks_cluster_endpoint" {
  value     = aws_eks_cluster.this.endpoint
  sensitive = true
}

output "kubectl_config_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name}"
}

output "backend_image_uri" {
  value = "${aws_ecr_repository.backend.repository_url}:latest"
}

output "frontend_image_uri" {
  value = "${aws_ecr_repository.frontend.repository_url}:latest"
}

output "sqs_bets_queue_url" {
  value = aws_sqs_queue.bets.url
}

output "sqs_settlement_queue_url" {
  value = aws_sqs_queue.settlement.url
}

output "sns_topic_arn" {
  value = aws_sns_topic.app.arn
}

output "load_balancer_controller_status_command" {
  value = "kubectl -n kube-system get deploy aws-load-balancer-controller"
}
