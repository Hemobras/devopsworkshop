CI/CD do devopsworkshop 🚀

Este README descreve um pipeline CI/CD recomendado para a aplicação devopsworkshop (build de imagem, testes, push para registry e deploy em Kubernetes). Está pensado para GitHub Actions + Docker Hub + cluster Kubernetes (Kind, Minikube ou cluster remoto). Ajuste nomes, secrets e endereços conforme seu ambiente.

Badges
![build](https://github.com/<ORG>/<REPO>/actions/workflows/ci.yml/badge.svg)
![deploy](https://github.com/<ORG>/<REPO>/actions/workflows/deploy.yml/badge.svg)
(substitua <ORG>/<REPO>)

Sumário

Visão geral

Requisitos

Pipelines (CI e CD) — exemplos de GitHub Actions

Variáveis/Secrets necessárias

Deploy local (kind) — comandos úteis

Rollback / troubleshooting rápido

Visão geral

O objetivo do pipeline:

Validar código (linters, unit tests).

Construir artefato (Docker image).

Publicar imagem em registry (Docker Hub / GHCR).

Fazer deploy no cluster Kubernetes (produção ou ambiente de staging) e validar health via readiness/liveness probes.

Notificar/registrar status (Slack, Teams, ou GitHub checks).

Requisitos

Conta GitHub (repositório configurado).

Registry de container (Docker Hub ou GitHub Container Registry).

Cluster Kubernetes acessível pelo CI (kubeconfig via secret) ou uso de kubectl em runner auto-hospedado.

Secrets configurados no GitHub: DOCKER_USERNAME, DOCKER_PASSWORD, KUBE_CONFIG_DATA (base64 do kubeconfig) ou outros conforme sua infra.

Exemplo: GitHub Actions — CI (.github/workflows/ci.yml)

Arquivo de exemplo com lint, tests e build da imagem (e push ao registry quando em main):

name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test-and-build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Node (if frontend)
        uses: actions/setup-node@v4
        with:
          node-version: '18'

      - name: Install deps
        run: |
          npm ci

      - name: Lint
        run: |
          npm run lint

      - name: Unit tests
        run: |
          npm test -- --ci --reporter=default

      - name: Build production
        run: |
          npm run build

      - name: Log in to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push image
        uses: docker/build-push-action@v4
        with:
          push: true
          tags: ${{ secrets.DOCKER_USERNAME }}/devopsworkshop:${{ github.sha }}
          file: ./Dockerfile

Exemplo: GitHub Actions — CD (.github/workflows/deploy.yml)

Faz deploy ao Kubernetes quando a imagem for criada em main (ou tag semântica).

name: CD

on:
  push:
    branches: [ main ]
    tags:
      - 'v*.*.*'

jobs:
  deploy:
    runs-on: ubuntu-latest
    needs: test-and-build
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: '1.30.0'

      - name: Configure kubeconfig
        env:
          KUBECONFIG_B64: ${{ secrets.KUBE_CONFIG_DATA }}
        run: |
          echo "$KUBECONFIG_B64" | base64 --decode > kubeconfig
          export KUBECONFIG="$PWD/kubeconfig"
          kubectl version --short

      - name: Update deployment image
        env:
          IMAGE: ${{ secrets.DOCKER_USERNAME }}/devopsworkshop:${{ github.sha }}
        run: |
          kubectl -n tech-local set image deployment/noir-frontend noir-frontend="$IMAGE" --record
          kubectl -n tech-local rollout status deployment/noir-frontend --timeout=2m

      - name: Post-deploy checks
        run: |
          kubectl -n tech-local get pods -l app=noir-frontend -o wide


Observação: preferível usar tags semânticas para releases (docker push ...:v1.2.3) e atualizar a imagem no deployment por tag. Para pipelines mais seguros, crie um job promote-to-prod que roda manualmente (workflow_dispatch).

Secrets / Variáveis necessárias

DOCKER_USERNAME — usuário do registry.

DOCKER_PASSWORD — senha/token do registry.

KUBE_CONFIG_DATA — conteúdo do kubeconfig codificado em base64 (se o runner precisa acessar o cluster).

IMG_REGISTRY (opcional) — ex: docker.io/marlonanderson.

SLACK_WEBHOOK (opcional) — notificação.

No GitHub: Repo > Settings > Secrets and variables > Actions.

Deploy local com Kind (para desenvolvimento)

Comandos úteis para testar o fluxo localmente:

# criar cluster kind
kind create cluster --name devopsworkshop

# buildar imagem localmente
docker build -t marlonanderson/noir-frontend:local .

# carregar imagem no cluster kind
kind load docker-image marlonanderson/noir-frontend:local --name devopsworkshop

# aplicar manifest Kubernetes
kubectl apply -f k8s/deployment.yaml -n tech-local

# ver rollout
kubectl -n tech-local rollout status deployment/noir-frontend

# ver pods
kubectl -n tech-local get pods -o wide

# tail logs
kubectl -n tech-local logs -l app=noir-frontend -f

Recomendações de manifests Kubernetes

Configure readinessProbe e livenessProbe (evita ProgressDeadlineExceeded por probes apontando para porta errada).

Exemplo de readiness/liveness (ajuste porta conforme listen do nginx):

readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3

livenessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3


Use imagePullPolicy: IfNotPresent para ambientes de dev/Kind, Always para CI que empurra imagens por tag.

Rollback rápido
# ver histórico do rollout
kubectl -n tech-local rollout history deployment/noir-frontend

# voltar para a revisão anterior
kubectl -n tech-local rollout undo deployment/noir-frontend

Troubleshooting comum

ProgressDeadlineExceeded: geralmente probes falhando — confirme containerPort e listen do servidor.

Pod CrashLoopBackOff: ver logs kubectl logs.

Imagem não encontrada: confirme image e se o registry aceita pull sem autenticação; se privado, configure imagePullSecrets.

Probes com timeout: aumente timeoutSeconds e initialDelaySeconds se a aplicação demora para iniciar.

Boas práticas

Proteja branch main com branch protection + required checks (CI green).

Use tags imutáveis (v1.2.3) no deploy para rastreabilidade.

Tenha separação de ambientes (staging/prod) e pipelines de promoção.

Executar escaneamento de vulnerabilidades da imagem (Trivy, Snyk) no CI.

Exemplo de estrutura de diretórios (sugerida)
/
├─ .github/
│  ├─ workflows/
│  │  ├─ ci.yml
│  │  └─ deploy.yml
├─ k8s/
│  ├─ deployment.yaml
│  ├─ service.yaml
│  └─ ingress.yaml
├─ src/
├─ Dockerfile
└─ README.md


Se quiser eu:

gero os dois workflows (CI + CD) prontos com seus valores substituíveis;

monto deployment.yaml com readiness/liveness e exemplos de ingress;

ou adapto o README em inglês.

Qual prefere que eu gere agora? Vou criar os arquivos do GitHub Actions e o deployment.yaml (especifique se quer porta 80 ou 8080).

monte um readme para esse app relativo a CI-CD

Aqui está um README.md completo, profissional e pronto para uso, focado no CI/CD do seu projeto devopsworkshop no GitHub — incluindo build, testes, Docker, push para registry e deploy em Kubernetes (Kind, homolog ou produção).

🚀 Pipeline CI/CD – DevOps Workshop

Este repositório demonstra uma pipeline completa de Integração Contínua (CI) e Entrega Contínua (CD) utilizando GitHub Actions, Docker, Kind (Kubernetes local) e deployment automatizado.

A pipeline foi projetada para ser simples, reprodutível e adequada tanto para ambientes locais, quanto para clusters Kubernetes reais.

📌 Funcionalidades do CI/CD

A pipeline executa as seguintes etapas:

1. Integração Contínua (CI)

✔️ Checkout do repositório
✔️ Instalação de dependências (Node.js, Python ou outra stack usada)
✔️ Execução dos testes automatizados
✔️ Lint e validações
✔️ Build da aplicação

2. Containerização

✔️ Construção da imagem Docker
✔️ Tag automática baseada no commit
✔️ Push da imagem para Docker Hub (ou outro registry)

3. Deploy Contínuo (CD)

✔️ Deploy automático em:

Ambiente local (Kind)

Ambiente de homologação

Ambiente de produção (opcional)

✔️ Atualização do Deployment
✔️ Estratégia de rollout nativa do Kubernetes (Rolling Update)

🏗 Arquitetura Simplificada da Pipeline
┌──────────────┐
│   Git Push    │
└───────┬──────┘
        ▼
┌───────────────────────┐
│ GitHub Actions (CI/CD) │
└───────┬───────────────┘
        ▼
┌────────────────────────────────┐
│ Build + Test + Lint            │
└───────┬────────────────────────┘
        ▼
┌────────────────────────────────┐
│ Docker Build & Push Registry   │
└───────┬────────────────────────┘
        ▼
┌─────────────────────────────────────┐
│ Deploy Kubernetes (Kind/Homolog/Prod)│
└─────────────────────────────────────┘

⚙️ GitHub Actions – Arquivo do Workflow

Coloque em:

.github/workflows/cicd.yaml

name: CI-CD DevOps Workshop

on:
  push:
    branches: [ "main" ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install Dependencies
        run: npm install

      - name: Run Tests
        run: npm test --if-present

      - name: Docker Login
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USER }}
          password: ${{ secrets.DOCKER_PASS }}

      - name: Build Docker Image
        run: |
          docker build -t ${{ secrets.DOCKER_USER }}/devopsworkshop:${{ github.sha }} .

      - name: Push Image
        run: |
          docker push ${{ secrets.DOCKER_USER }}/devopsworkshop:${{ github.sha }}

  deploy:
    needs: build
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Create Kind Cluster
        uses: helm/kind-action@v1.8.0
        with:
          cluster_name: devops-local

      - name: Apply Kubernetes Manifests
        run: |
          kubectl set image deployment/devops-app \
            app=${{ secrets.DOCKER_USER }}/devopsworkshop:${{ github.sha }} --namespace default

🔐 Configuração de Secrets Necessários

No GitHub → Settings → Secrets and Variables > Actions

Nome	Descrição
DOCKER_USER	Usuário do Docker Hub
DOCKER_PASS	Senha ou token do Docker Hub
📦 Estrutura do Projeto
/
├── src/                     # código da aplicação
├── Dockerfile               # build container
├── k8s/
│   ├── deployment.yaml      # deployment Kubernetes
│   ├── service.yaml         # service Kubernetes
├── .github/
│   └── workflows/
│       └── cicd.yaml        # pipeline CI/CD
└── README.md

🐳 Exemplo de Dockerfile
FROM node:20-alpine

WORKDIR /app
COPY package*.json ./

RUN npm install --production

COPY . .

EXPOSE 8080
CMD ["npm", "start"]

☸️ Deploy Manual (caso deseje testar sem CI)
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml


Atualizar imagem manualmente:

kubectl set image deployment/devops-app app=marlonanderson/devopsworkshop:tag

