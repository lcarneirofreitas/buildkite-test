#!/bin/bash

set -e

echo "🔍 Verificando labels do PR..."

GITHUB_TOKEN=$(buildkite-agent secret get GITHUB_TOKEN)
PR_NUMBER=$(buildkite-agent meta-data get "pull_request_number")

# Pega as labels do PR
RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/lcarneirofreitas/buildkite-test/issues/$PR_NUMBER/labels")

LABELS=$(echo "$RESPONSE" | jq -r '.[].name' | tr '\n' ' ')

echo "📌 Labels encontradas: $LABELS"

PIPELINE_STEPS="[]"

if echo "$LABELS" | grep -qw "dev"; then
  echo "✅ Configurando deploy para DEV..."
  PIPELINE_STEPS=$(jq -n \
    --argjson steps "$PIPELINE_STEPS" \
    --arg env "dev" \
    '{ steps: $steps + [ { label: "Deploy para DEV", command: ".buildkite/deploy.sh dev" } ] }')
elif echo "$LABELS" | grep -qw "preprod"; then
  echo "✅ Configurando deploy para PREPROD..."
  PIPELINE_STEPS=$(jq -n \
    --argjson steps "$PIPELINE_STEPS" \
    --arg env "preprod" \
    '{ steps: $steps + [ { label: "Deploy para PREPROD", command: ".buildkite/deploy.sh preprod" } ] }')
elif echo "$LABELS" | grep -qw "production"; then
  echo "✅ Configurando deploy para PRODUCTION..."
  PIPELINE_STEPS=$(jq -n \
    --argjson steps "$PIPELINE_STEPS" \
    --arg env "production" \
    '{ steps: $steps + [ { label: "Deploy para PRODUCTION", command: ".buildkite/deploy.sh production" } ] }')
else
  echo "🚨 Nenhuma label válida encontrada. Cancelando build."
  buildkite-agent annotate "Pipeline cancelado: Nenhuma label válida encontrada." --style "error"
  exit 1
fi

# Faz o upload do pipeline dinâmico para o Buildkite
echo "$PIPELINE_STEPS" | buildkite-agent pipeline upload
