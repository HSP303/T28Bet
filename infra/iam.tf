data "aws_iam_roles" "available" {
  path_prefix = "/"
}

locals {
  available_iam_role_names = toset(data.aws_iam_roles.available.names)

  eks_cluster_role_candidates = distinct(compact([
    var.eks_cluster_role_name,
    "LabEksClusterRole",
    "LabRole",
  ]))

  eks_node_role_candidates = distinct(compact([
    var.eks_node_role_name,
    "LabEksNodeRole",
    "LabRole",
  ]))

  eks_cluster_role_name = one([
    for candidate in local.eks_cluster_role_candidates : candidate
    if contains(local.available_iam_role_names, candidate)
  ])

  eks_node_role_name = one([
    for candidate in local.eks_node_role_candidates : candidate
    if contains(local.available_iam_role_names, candidate)
  ])
}

data "aws_iam_role" "eks_cluster" {
  name = local.eks_cluster_role_name
}

data "aws_iam_role" "eks_node" {
  name = local.eks_node_role_name
}
