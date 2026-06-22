# Terraform AWS Lab - EKS + MongoDB + SQS + SNS + CloudWatch + ECR

Infraestrutura genérica para laboratório AWS.

## Recursos provisionados

- VPC customizada
- Subnets públicas e privadas
- Internet Gateway
- NAT Gateway opcional
- EKS Cluster
- EKS Managed Node Group com mínimo de 3 instâncias
- AWS Load Balancer Controller via Helm
- MongoDB no Kubernetes para o backend da aplicação
- Duas filas SQS: apostas e liquidação
- SNS para notificações de resultado
- Repositórios ECR para backend e frontend
- CloudWatch Log Groups
- CloudWatch Alarms básicos
- HPA opcional com `metrics-server` desligado por padrão no lab

## Pré-requisitos

No terminal:

```bash
aws sts get-caller-identity
terraform -version
kubectl version --client
helm version
```

## Como usar

Copie o exemplo de variáveis:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Inicialize:

```bash
terraform init
```

Valide:

```bash
terraform validate
```

Planeje:

```bash
terraform plan
```

Aplique:

```bash
terraform apply
```

Configure o kubectl:

```bash
aws eks update-kubeconfig --region us-east-1 --name lab-eks-app
```

Valide o cluster:

```bash
kubectl get nodes
kubectl get pods -A
kubectl -n kube-system get deploy aws-load-balancer-controller
```

Exporte os outputs do Terraform usados no ECR e no Kubernetes:

```bash
terraform output -raw backend_image_uri
terraform output -raw frontend_image_uri
terraform output -raw redis_url
terraform output -raw sqs_bets_queue_url
terraform output -raw sqs_settlement_queue_url
terraform output -raw sns_topic_arn
```

Se o seu lab expuser nomes diferentes para os roles do EKS, ajuste `eks_cluster_role_name` e `eks_node_role_name` no `terraform.tfvars`.

Faça build e push das imagens para o ECR:

```bash
./scripts/build-and-push-ecr.sh
```

Fluxo operacional do lab:

```bash
./scripts/update-kubeconfig.sh
./scripts/apply-k8s.sh
./scripts/seed.sh
./scripts/check-pods.sh
./scripts/logs.sh backend
./scripts/destroy-lab.sh
```

Depois atualize os Deployments para usar as URIs do ECR:

```bash
kubectl set image deployment/backend backend="$(terraform -chdir=infra output -raw backend_image_uri)" -n t28bet
kubectl set image deployment/frontend frontend="$(terraform -chdir=infra output -raw frontend_image_uri)" -n t28bet
```

## Exemplo de Load Balancer público

Depois que o Terraform terminar:

```bash
kubectl apply -f k8s/example-public-alb.yaml
kubectl get ingress -n lab-app
```

## Exemplo de Load Balancer interno

```bash
kubectl apply -f k8s/example-internal-nlb.yaml
kubectl get svc -n lab-app
```

## Destruir tudo

```bash
kubectl delete -f k8s/example-public-alb.yaml --ignore-not-found
kubectl delete -f k8s/example-internal-nlb.yaml --ignore-not-found
terraform destroy
```

## Observações importantes para laboratório

- `enable_nat_gateway = true` facilita o funcionamento dos nodes privados, mas NAT Gateway gera custo.
- O banco principal da aplicação é MongoDB via Kubernetes (`k8s/mongo/*`), usando `MONGO_URI` apontando para `mongo-svc`.
- Os manifests `k8s/backend/deployment.yaml` e `k8s/frontend/deployment.yaml` usam placeholders de imagem do ECR e devem ser preenchidos com `terraform output -raw backend_image_uri` e `terraform output -raw frontend_image_uri`.
- O frontend conversa com o backend pelo mesmo host do ALB usando caminhos relativos (`/api` e `/ws`); em local, o CRA proxy repassa essas chamadas para `localhost:3001`.
- No modelo simples de laboratório, `k8s/configmap.yaml` carrega configurações não sensíveis e `k8s/secret.yaml` carrega os endpoints/segredos manualmente copiados dos outputs do Terraform.
- O backend e o controller usam os papéis preexistentes do Learner Lab; não há criação de roles IAM customizadas no Terraform.
- Se o seu laboratório usar nomes diferentes para os roles do EKS, sobrescreva `eks_cluster_role_name` e `eks_node_role_name` no `terraform.tfvars`.
- A política IAM do AWS Load Balancer Controller está simplificada para laboratório. Em produção, substitua por política mais restritiva.
- O pacote simples de observabilidade mantém apenas o alarme de erro da aplicação baseado nos logs.
- `metrics-server` e `amazon-cloudwatch-observability` ficam desligados por padrão para reduzir o risco de bootstrap falhar no Learner Lab.
- O perfil estável do laboratório usa nodes `t3.small`, backend com 1 réplica, HPA limitado e MongoDB com PVC pequeno para reduzir consumo de memória e disco.
