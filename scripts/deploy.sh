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

#  改行コードを変数LFに設定
LF="
"

LOAD_BALANCER_ARN=$(aws elbv2 describe-load-balancers --names ${SYSTEM_ID}-alb-${SYSTEM_ID}-front | jq -r '.LoadBalancers[].LoadBalancerArn')
echo "testing" 
echo ${LOAD_BALANCER_ARN}
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn ${LOAD_BALANCER_ARN} | jq -r '.TargetGroups[0].TargetGroupArn')

# confから取得(ドメイン固有)
PARAMS=$(cat envs/${ENV_ID}.conf | grep -v '^ *#' | grep -e '^.*=.*$' | sed "s/^\(.*\)=\(.*\)$/\1='\2'/g")
# CloudFormationからシェル変数に取得した値をパラメータ群に追加
PARAMS="${PARAMS}${LF}CompanyId='${COMPANY_ID}'"
PARAMS="${PARAMS}${LF}SystemId='${SYSTEM_ID}'"
PARAMS="${PARAMS}${LF}EnvId='${ENV_ID}'"
PARAMS="${PARAMS}${LF}EnvName='${ENVNAME}'"
PARAMS="${PARAMS}${LF}SystemName='${SYSTEM_NAME}'"
PARAMS="${PARAMS}${LF}ActiveTargetGroupArn='${TARGET_GROUP_ARN}'"
PARAMS="${PARAMS}${LF}"

SUB_SYSTEM_ID=$(cat envs/${ENV_ID}.conf | grep ^SubSystemId | head -1 | cut -d= -f2-)
S3_CICD_BUCKET_NAME=$(cat envs/${ENV_ID}.conf | grep ^S3CicdBucketName | head -1 | cut -d= -f2-)
CICD_REPOSITORY=$(cat envs/${ENV_ID}.conf | grep ^CicdRepository | head -1 | cut -d= -f2-)
#  後続のコマンドでecho | bash しているため、エスケープでダブルクォーテーションを保護
# SYSTEM_NAME_SHELL="\"Core System Migration Project\""


PARAMS_star=$(cat envs/${ENV_ID}.conf | grep -v '^ *#' | grep '*' | grep -e '^.*=.*$' | sed "s/^\(.*\)=\(.*\)$/\1='\2'/g")
#
# 変数名の末尾に^を入れることで、先頭を大文字に変換
# STACK_NAME_PREFIX=${COMPANY_ID}${SYSTEM_ID}${SUB_SYSTEM_ID}${ENV_ID}
STACK_NAME_PREFIX=${COMPANY_ID^}${SYSTEM_ID^}${SUB_SYSTEM_ID^}${ENV_ID^}

echo """
===============================
Parameters
===============================
${PARAMS}
===============================
"""



############################
# 共通関数定義
############################
deploy_stack () {
  # テンプレートファイルの指定有無確認
  if [ "$#" -gt 1 ]; then
    STACK_NAME=${1}
    TEMPLATE_FILE_OPT="--template-file ${2}"
  else
    STACK_NAME=${1}
    TEMPLATE_FILE_OPT=""
  fi

  # 対象スタックが ROLLBACK_COMPLETE ステータスの場合は sam delete を実行
  NUM_ROLLBACK_COMPLETE=$(aws cloudformation list-stacks | jq '.StackSummaries[] | select(.StackName == "'${STACK_NAME}'" and .StackStatus == "ROLLBACK_COMPLETE")' | wc -l)
  if [ ${NUM_ROLLBACK_COMPLETE} -gt 0 ]; then sam delete --stack-name ${STACK_NAME} --no-prompts --region ap-northeast-1; fi

  # sam deploy の実行
  echo sam deploy \
    --stack-name ${STACK_NAME} \
    ${TEMPLATE_FILE_OPT} \
    --parameter-overrides \"${PARAMS} """${PARAMS_star}"""\" \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset \
    --region ap-northeast-1 \
    --no-confirm-changeset \
    | bash
}


############################
# メイン処理
############################
sam build && deploy_stack ${STACK_NAME_PREFIX}BatchStack
# sam build && deploy_stack ${STACK_NAME_PREFIX}InfraStack