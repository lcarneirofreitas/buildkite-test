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

if echo "$LABELS" | grep -qw "dev"; then
  echo "✅ Deploy para DEV"
  echo "BUILDKITE_TRIGGER_ENV=dev" >> "$BUILDKITE_ENV_FILE"
elif echo "$LABELS" | grep -qw "preprod"; then
  echo "✅ Deploy para PREPROD"
  echo "BUILDKITE_TRIGGER_ENV=preprod" >> "$BUILDKITE_ENV_FILE"
elif echo "$LABELS" | grep -qw "production"; then
  echo "✅ Deploy para PRODUCTION"
  echo "BUILDKITE_TRIGGER_ENV=production" >> "$BUILDKITE_ENV_FILE"
else
  echo "🚨 Nenhuma label válida encontrada. Cancelando build."
  buildkite-agent annotate "Pipeline cancelado: Nenhuma label válida encontrada." --style "error"
  exit 1
fi

