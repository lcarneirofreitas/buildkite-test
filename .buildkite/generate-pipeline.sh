#!/bin/bash

set -e

echo "🔍 Checking PR labels..."

# Retrieves the GitHub token from Buildkite secrets
GITHUB_TOKEN=$(buildkite-agent secret get GITHUB_TOKEN)

# Defines the repository correctly
REPO="lcarneirofreitas/buildkite-test"

# Attempts to get the PR number from the BUILDKITE_PULL_REQUEST variable
PR_NUMBER="${BUILDKITE_PULL_REQUEST}"

# If not set, try to retrieve it via GitHub API
if [[ -z "$PR_NUMBER" || "$PR_NUMBER" == "false" ]]; then
  echo "⚠️  PR number not found in BUILDKITE_PULL_REQUEST. Attempting to retrieve via API..."

  BRANCH="$BUILDKITE_BRANCH"

  PR_NUMBER=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/pulls" | jq -r --arg branch "$BRANCH" \
    '.[] | select(.head.ref == $branch) | .number')

  if [[ -z "$PR_NUMBER" || "$PR_NUMBER" == "null" ]]; then
    echo "🚨 No PR found for branch $BRANCH. Canceling build."
    buildkite-agent annotate "Pipeline canceled: No PR found." --style "error"
    exit 1
  fi
fi

echo "📌 PR number found: #$PR_NUMBER"

# Retrieves PR labels via GitHub API
RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO/issues/$PR_NUMBER/labels")

echo "🔍 Debug - API Response: $RESPONSE"

# Checks if the API response contains an error
if echo "$RESPONSE" | jq -e '.message? | select(. == "Not Found")' > /dev/null; then
  echo "🚨 Error: PR not found in repository $REPO!"
  exit 1
fi

# Extracts label names
LABELS=$(echo "$RESPONSE" | jq -r '.[].name' | tr '\n' ' ')

if [[ -z "$LABELS" ]]; then
  echo "🚨 No labels found. Canceling build."
  buildkite-agent annotate "Pipeline canceled: No labels found on PR." --style "error"
  exit 1
fi

echo "📌 Labels found: $LABELS"

# Initializes pipeline steps
PIPELINE_STEPS="[]"

# Defines the environment based on labels
if echo "$LABELS" | grep -qw "dev"; then
  ENV="dev"
  LABEL="Deploy to dev"
elif echo "$LABELS" | grep -qw "preprod"; then
  ENV="preprod"
  LABEL="Deploy to preprod"
elif echo "$LABELS" | grep -qw "production"; then
  ENV="production"
  LABEL="Deploy to production"
else
  echo "🚨 No valid label found. Canceling build."
  buildkite-agent annotate "Pipeline canceled: No valid label found." --style "error"
  exit 1
fi

echo "✅ Configuring $LABEL..."

# Adds the dynamic step to the pipeline
PIPELINE_STEPS=$(jq -n \
  --arg label "$LABEL" \
  --arg command "bash .buildkite/deploy.sh $ENV" \
  '{ steps: [ { label: $label, command: $command } ] }')

# Uploads the dynamic pipeline to Buildkite
echo "$PIPELINE_STEPS" | buildkite-agent pipeline upload
