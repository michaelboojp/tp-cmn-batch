# スクリプト実行用コンテナイメージ

## ビルド＆デプロイ手順

### docker login
```
ACCOUNT_ID=$(aws sts get-caller-identity | jq .Account -r)
docker build -t exec-athena-query-ecr .
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com
```

### docker build
```
docker build -t exec-athena-query-ecr .
```

### docker push
```
docker tag exec-athena-query-ecr:latest ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/exec-athena-query-ecr:latest
docker push ${ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/exec-athena-query-ecr:latest
```