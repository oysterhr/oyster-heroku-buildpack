#!/bin/sh

# `set –e` is used within the Bash to stop execution instantly as a query exits while having a non-zero status. 
# This function is also used when you need to know the error location in the running code
set -e

BUILD_DIR=$1
ENV_DIR=$3

# Get env variables
ROLE_ARN=$(cat "$ENV_DIR/ROLE_ARN")
ID_TOKEN=$(cat "$ENV_DIR/ID_TOKEN")
S3_BUCKET_NAME=$(cat "$ENV_DIR/S3_BUCKET_NAME")

if [ -z "$ROLE_ARN" ]; then
  echo "Skipping AWS sync. ROLE_ARN is not set"
  exit 0
fi

if [ -z "$ID_TOKEN" ]; then
  echo "Skipping AWS sync. ID_TOKEN is not set"
  exit 0
fi

if [ -z "$S3_BUCKET_NAME" ]; then
  echo "Skipping AWS sync. S3_BUCKET_NAME is not set"
  exit 0
fi

# Assume role
STS=($(aws sts assume-role-with-web-identity
      --role-arn ${ROLE_ARN}
      --role-session-name "${HEROKU_APP_NAME}-${HEROKU_RELEASE_VERSION}"
      --web-identity-token $ID_TOKEN
      --duration-seconds 3600
      --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]'
      --output text))
export AWS_ACCESS_KEY_ID="${STS[0]}"
export AWS_SECRET_ACCESS_KEY="${STS[1]}"
export AWS_SESSION_TOKEN="${STS[2]}"

# Sync bucket
PUBLIC_FOLDER="$BUILD_DIR/public"
aws s3 sync $PUBLIC_FOLDER s3://$S3_BUCKET_NAME

# Invalidate cache
# We need to invalidate the cache for manifest.json and manifest-assets.json
# So users get the last hash versioning
aws cloudfront create-invalidation --distribution-id $HEROKU_RELEASE_VERSION --paths "/manifest.json" "/manifest-assets.json" --no-cli-pager