#!/bin/bashexport
#
# vim: ai nonu ic ts=4 sw=4
#
# 機能概要：s3ファイルのコピー
#
# 変更履歴     担当者                  備考
# ----------- ----------------------- -------------------------------------------
# 2023/01/23   包　照                新規作成
#
# ECS環境変数：
#	  ENV_SRC_BUCKET       コピー元バケット名
#	  ENV_SRC_PATH         コピー元パス
#	  ENV_SRC_FILE         コピー元ファイル名
#	  ENV_DST_BUCKET       コピー先バケット名
#	  ENV_DST_PATH         コピー先パス
# 説明：
#	  S3のファイルをコピーする（バックアップなど）
#----------------------------------------
# 前処理
#----------------------------------------
# debug
ENV_SRC_BUCKET='tp-bao-s3-cmn-batch3-dev'
ENV_SRC_PATH='from'
ENV_SRC_FILE='data.txt'
ENV_DST_BUCKET='tp-bao-s3-cmn-batch3-dev'
ENV_DST_PATH='to'



# 環境変数名の確認
if [ $ENV_SRC_BUCKET = "_PLACEHOLDER_" ]; then
    echo "環境変数内の値が不正です。"
    echo "コンテナ実行時の環境変数設定を見直してください。"
    exit 1
fi

if [ $ENV_SRC_PATH = "_PLACEHOLDER_" ]; then
    echo "環境変数内の値が不正です。"
    echo "コンテナ実行時の環境変数設定を見直してください。"
    exit 1
fi

if [ $ENV_SRC_FILE = "_PLACEHOLDER_" ]; then
    echo "環境変数内の値が不正です。"
    echo "コンテナ実行時の環境変数設定を見直してください。"
    exit 1
fi

if [ $ENV_DST_BUCKET = "_PLACEHOLDER_" ]; then
    echo "環境変数内の値が不正です。"
    echo "コンテナ実行時の環境変数設定を見直してください。"
    exit 1
fi

if [ $ENV_DST_PATH = "_PLACEHOLDER_" ]; then
    echo "環境変数内の値が不正です。"
    echo "コンテナ実行時の環境変数設定を見直してください。"
    exit 1
fi

#----------------------------------------
# 主処理 コピー
#----------------------------------------
# ファイルコピーする
rmsg=$(aws s3 cp s3://$ENV_SRC_BUCKET/$ENV_SRC_PATH/$ENV_SRC_FILE s3://$ENV_DST_BUCKET/$ENV_DST_PATH/)
rc=$?

#debug
#echo $rc

# メッセージ処理（要るかな？）
if [ $rc != 0 ]; then
  echo 'エラー'
else
  echo '正常終了'
fi

#----------------------------------------
# 後処理
#----------------------------------------
exit $rc