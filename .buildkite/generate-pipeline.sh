#!/bin/bash

set -e

echo "🔍 Verificando labels do PR..."

# Obtém o token do GitHub a partir do Buildkite secrets
GITHUB_TOKEN=$(buildkite-agent secret get GITHUB_TOKEN)

# Define o repositório corretamente
REPO="lcarneirofreitas/buildkite-test"

# Tenta obter o número do PR a partir da variável BUILDKITE_PULL_REQUEST
PR_NUMBER="${BUILDKITE_PULL_REQUEST}"

# Se não estiver definido, tenta recuperar via API do GitHub
if [[ -z "$PR_NUMBER" || "$PR_NUMBER" == "false" ]]; then
  echo "⚠️  Número do PR não encontrado em BUILDKITE_PULL_REQUEST. Tentando recuperar via API..."

  BRANCH="$BUILDKITE_BRANCH"

  PR_NUMBER=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/pulls" | jq -r --arg branch "$BRANCH" \
    '.[] | select(.head.ref == $branch) | .number')

  if [[ -z "$PR_NUMBER" || "$PR_NUMBER" == "null" ]]; then
    echo "🚨 Nenhum PR encontrado para a branch $BRANCH. Cancelando build."
    buildkite-agent annotate "Pipeline cancelado: Nenhum PR encontrado." --style "error"
    exit 1
  fi
fi

echo "📌 Número do PR encontrado: #$PR_NUMBER"

# Obtém as labels do PR via API do GitHub
RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO/issues/$PR_NUMBER/labels")

echo "🔍 Debug - Resposta da API: $RESPONSE"

# Verifica se a resposta da API contém erro
if echo "$RESPONSE" | jq -e '.message? | select(. == "Not Found")' > /dev/null; then
  echo "🚨 Erro: PR não encontrado no repositório $REPO!"
  exit 1
fi

# Extrai os nomes das labels
LABELS=$(echo "$RESPONSE" | jq -r '.[].name' | tr '\n' ' ')

if [[ -z "$LABELS" ]]; then
  echo "🚨 Nenhuma label encontrada. Cancelando build."
  buildkite-agent annotate "Pipeline cancelado: Nenhuma label encontrada no PR." --style "error"
  exit 1
fi

echo "📌 Labels encontradas: $LABELS"

# Inicializa os steps do pipeline
PIPELINE_STEPS="[]"

# Define o ambiente com base nas labels
if echo "$LABELS" | grep -qw "dev"; then
  ENV="dev"
  LABEL="Deploy para DEV"
elif echo "$LABELS" | grep -qw "preprod"; then
  ENV="preprod"
  LABEL="Deploy para PREPROD"
elif echo "$LABELS" | grep -qw "production"; then
  ENV="production"
  LABEL="Deploy para PRODUCTION"
else
  echo "🚨 Nenhuma label válida encontrada. Cancelando build."
  buildkite-agent annotate "Pipeline cancelado: Nenhuma label válida encontrada." --style "error"
  exit 1
fi

echo "✅ Configurando $LABEL..."

# Adiciona o step dinâmico no pipeline
PIPELINE_STEPS=$(jq -n \
  --arg label "$LABEL" \
  --arg command ".buildkite/deploy.sh $ENV" \
  '{ steps: [ { label: $label, command: $command } ] }')

# Faz o upload do pipeline dinâmico para o Buildkite
echo "$PIPELINE_STEPS" | buildkite-agent pipeline upload
