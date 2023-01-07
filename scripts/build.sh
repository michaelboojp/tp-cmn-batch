#!/bin/bash -eu



############################
# パラメータチェック
############################
if [ $# -ne 1 ]; then
  echo
  echo "[Error] 引数(環境識別子)を入力してください" 1>&2
  echo "  $ bash scripts/deploy.sh dev" 1>&2
  echo
  exit 1
else
  ENV_ID=${1,,}
fi



############################
# 定数定義
############################
# CloudFormationから取得(全ドメインで共通)
COMPANY_ID=$(aws cloudformation list-exports | jq '[.Exports[]]' | jq 'map(select( .Name == "'${ENV_ID}'-cmn-CompanyId" ))' | jq '.[].Value' | head -1  | sed 's/"//g' )
SYSTEM_ID=$(aws cloudformation list-exports | jq '[.Exports[]]' | jq 'map(select( .Name == "'${ENV_ID}'-cmn-SystemId" ))' | jq '.[].Value' | head -1  | sed 's/"//g' )
ENVNAME=$(aws cloudformation list-exports | jq '[.Exports[]]' | jq 'map(select( .Name == "'${ENV_ID}'-cmn-EnvName" ))' | jq '.[].Value' | head -1  | sed 's/"//g' )
SYSTEM_NAME=$(aws cloudformation list-exports | jq '[.Exports[]]' | jq 'map(select( .Name == "'${ENV_ID}'-cmn-SystemName" ))' | jq '.[].Value' | head -1  | sed 's/"//g' )

# confから取得(ドメイン固有)
SUB_SYSTEM_ID=$(cat envs/${ENV_ID}.conf | grep ^SubSystemId | head -1 | cut -d= -f2-)
DOCKER_TOKEN=$(cat envs/${ENV_ID}.conf | grep ^DockerToken | head -1 | cut -d= -f2-)
DOCKER_USER=$(cat envs/${ENV_ID}.conf | grep ^DockerUser | head -1 | cut -d= -f2-)

#AWS Cloudformation Exportから取得(infraリポジトリでExport)
SCRIPT_RUNNER_ECR_IMAGE_URI=$(aws cloudformation list-exports | jq '[.Exports[]]' | jq 'map(select( .Name == "'${ENV_ID}'-'${SUB_SYSTEM_ID}'-ECR-BatchScriptRunnerEcrRepositoryUri" ))' | jq '.[].Value' | head -1  | sed 's/"//g' | sed -e 's/$/:latest/');
#Debug
echo """
===============================
定数
===============================
SCRIPT_RUNNER_ECR_IMAGE_URI：${SCRIPT_RUNNER_ECR_IMAGE_URI}
===============================
"""



############################
# メイン処理
############################
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin $(echo ${SCRIPT_RUNNER_ECR_IMAGE_URI} | cut -d/ -f1)
echo $DOCKER_TOKEN | docker login -u $DOCKER_USER --password-stdin
docker build -t ${SCRIPT_RUNNER_ECR_IMAGE_URI} docker/script-runner
docker push ${SCRIPT_RUNNER_ECR_IMAGE_URI}