#!/usr/bin/env bash
# 爆爆数据 /v1 只读接口的统一调用器。
# 用法：bb.sh <path?query>    例：bb.sh '/v1/articles?platform=wx&order_by=read_num'
# 环境变量：BAOBAO_DATA_API_KEY（兼容旧名 MONAO_API_KEY），BAOBAO_DATA_BASE（默认 https://data.inkgai.com）
set -euo pipefail

KEY="${BAOBAO_DATA_API_KEY:-${MONAO_API_KEY:-}}"
BASE="${BAOBAO_DATA_BASE:-https://data.inkgai.com}"

if [ -z "$KEY" ]; then
  echo '{"error":{"code":"NO_KEY","message":"未配置 BAOBAO_DATA_API_KEY，请到 https://sso.inkgai.com/home/apikey 获取后 export"}}'
  exit 2
fi
if [ $# -ne 1 ] || [[ "$1" != /v1/* ]]; then
  echo '{"error":{"code":"BAD_ARGS","message":"用法：bb.sh /v1/<path>?<query>"}}'
  exit 2
fi

# 忽略用户 curl 配置，固定 GET、不跟随重定向；保留 HTTP 错误的 JSON 供调用方判断。
# --globoff 避免查询值中的方括号/花括号被 curl 展开成多次请求。
curl --disable --globoff --silent --show-error --max-time 30 --get \
  --header "X-API-KEY: $KEY" --header 'Accept: application/json' --url "${BASE%/}$1"
