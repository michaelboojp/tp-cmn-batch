#!/bin/bash

 ############################
 # パラメータチェック
 ############################
 if [ $# -lt 5 ]; then
   echo "実行するにはコピー元s3バケット、ファイルパスとコピー先s3バケット、ファイルパスを引数に指定して下さい。"
   exit 1
 fi
 SRC_S3_BUCKET_NAME="$1"
 SRC_S3_PATH="$2"
 SRC_S3_FILE_NAME="$3"
 DST_S3_BUCKET_NAME="$4"
 DST_S3_PATH="$5"


 ############################
 # 定数定義
 ############################
 export AWS_DEFAULT_REGION=ap-northeast-1
 export APP_ID="exec-s3copy"
 export SUB_SYSTEM_ID="cmn"


 ############################
 # パラメータストアから環境情報を取得
 ############################
 export INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
 #タグから取得(前後のダブルクオート削除)
 export ENV_ID=`aws ec2 describe-instances --instance-ids "${INSTANCE_ID}" --query 'Reservations[0].Instances[0].Tags[?Key==\`Env\`]|[0].Value' | sed "s/\"//g"`

 ############################
 # Configファイルを読み込み
 # コンテナ実行に必要な情報を作成
 ############################
 # コンテナ共通
 export COMPANY_ID=`aws cloudformation list-exports --query "Exports[?Name=='${ENV_ID}-cmn-CompanyId'].Value" --output text`
 export SYSTEM_ID=`aws cloudformation list-exports --query "Exports[?Name=='${ENV_ID}-cmn-SystemId'].Value" --output text`
 export SUBNET_1=`aws cloudformation list-exports --query "Exports[?Name=='${ENV_ID}-cmn-PriLSubnet1'].Value" --output text`
 export SUBNET_2=`aws cloudformation list-exports --query "Exports[?Name=='${ENV_ID}-cmn-PriLSubnet2'].Value" --output text`
 export SECURITY_GROUP_ID=`aws cloudformation list-exports --query "Exports[?Name=='${ENV_ID}-cmn-SG-BatchEcsSecurityGroupId'].Value" --output text`
 export CLUSTER_ARN=$(aws ecs list-clusters | jq '.clusterArns[] | select(test("'^.*\/${SUB_SYSTEM_ID}-ecscluster-${ENV_ID}-batch\$'"))' -r)
 export TASK_DEFINITION_ARN_ARY=$(aws ecs list-task-definitions | jq '.taskDefinitionArns[] | select( test("'^.*\/${SUB_SYSTEM_ID}-ecstask-${ENV_ID}-batch-${APP_ID}:\[0-9\]+\$'") )' -r)

 # 最新のタスク定義を取得
 TASK_DEFINITION_ARN=""
 LATEST_VERSION=0
 for ARN in $TASK_DEFINITION_ARN_ARY; do
             #echo $ARN
             VERSION=${ARN##*\:}
             if [ $VERSION -gt $LATEST_VERSION ]; then
                     TASK_DEFINITION_ARN=$ARN
                     LATEST_VERSION=$VERSION
             fi
 done

 export CONTAINER_NAME=$(aws ecs describe-task-definition --task-definition ${TASK_DEFINITION_ARN} | jq '.taskDefinition.containerDefinitions[0].name' -r)

 # 個別設定
 export CONTAINER_OVERRIDE='{
     "containerOverrides": [{
         "name": "'${CONTAINER_NAME}'",
         "command": ["bash -eux scripts/'${APP_ID}'.sh"],
         "environment": [
             {
                 "name": "ENV_SRC_BUCKET",
                 "value": "'${SRC_S3_BUCKET_NAME}'"
             },
             {
                 "name": "ENV_SRC_PATH",
                 "value": "'${SRC_S3_PATH}'"
             },
             {
                 "name": "ENV_SRC_FILE",
                 "value": "'${SRC_S3_FILE_NAME}'"
             },
             {
                 "name": "ENV_DST_BUCKET",
                 "value": "'${DST_S3_BUCKET_NAME}'"
             },
             {
                 "name": "ENV_DST_PATH",
                 "value": "'${DST_S3_PATH}'"
             }
         ]
     }]
 }'
 # debug
 # echo $CONTAINER_OVERRIDE

 ############################
 # メイン処理
 ############################
 # run-task コマンドの実行
 RUN_TASK_RESULT=$(aws ecs run-task --launch-type FARGATE \
     --cluster "${CLUSTER_ARN}" \
     --task-definition "${TASK_DEFINITION_ARN}" \
     --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_1},${SUBNET_2}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=DISABLED}" \
     --overrides "${CONTAINER_OVERRIDE}")
 TASK_ARN=$(echo ${RUN_TASK_RESULT} | jq .tasks[0].taskArn -r)

 # ステータスが STOPPED になるまで待つ
 aws ecs wait tasks-stopped --cluster "${CLUSTER_ARN}" --tasks "${TASK_ARN}"

 # describe-tasks コマンドの実行
 DESCRIBE_TASK_RESULT=$(aws ecs describe-tasks --cluster "${CLUSTER_ARN}" --tasks "${TASK_ARN}")
 STATUS=$(echo ${DESCRIBE_TASK_RESULT} | jq .tasks[0].lastStatus -r)
 EXIT_CODE=$(echo ${DESCRIBE_TASK_RESULT} | jq .tasks[0].containers[0].exitCode -r)
 STOPPED_REASON=$(echo ${DESCRIBE_TASK_RESULT} | jq .tasks[0].stoppedReason -r)

 echo "[INFO]: Task stopped with exitCode=[${EXIT_CODE}], stoppedReason=[\"${STOPPED_REASON}\"]".

 rc=${EXIT_CODE}

 exit $rc