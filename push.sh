#!/bin/bash
# push.sh —— 提交推送数据 + 清除 jsDelivr CDN 缓存
#
# jsDelivr 对分支引用（@main）有最长约 12 小时缓存，推送后数据不会立即生效。
# 本脚本在 git push 之后自动调用 jsDelivr 官方的免费清缓存接口
# （https://purge.jsdelivr.net，无需任何账号），让小程序立即拿到最新数据。
#
# 用法：
#   ./push.sh "提交说明"
set -euo pipefail
cd "$(dirname "$0")"

msg="${1:-update data}"

git add -A
if git diff --cached --quiet; then
  echo "==> 没有需要提交的改动"
else
  git commit -m "$msg"
fi

echo "==> 推送到 GitHub..."
git push

echo "==> 清除 jsDelivr CDN 缓存..."
purge() {
  local path="$1"
  local res
  if ! res=$(curl -sf --max-time 15 "https://purge.jsdelivr.net/gh/wcy21k/static_stock@main/$path"); then
    echo "    ✗ $path（请求失败，可稍后手动访问 https://purge.jsdelivr.net/gh/wcy21k/static_stock@main/$path 重试）"
    return
  fi
  if echo "$res" | grep -q '"status":"finished"'; then
    echo "    ✓ $path"
  else
    echo "    ✗ $path（返回：$res）"
  fi
}

# 固定清除 5 个数据文件
for f in us-stocks.json a-stocks.json jp-stocks.json kr-stocks.json us-sample-trades.json; do
  purge "json/$f"
done

# 最近一次提交里改动的其它文件（如新增的 logo 图片）也一并清除
if git rev-parse --verify ORIG_HEAD >/dev/null 2>&1; then
  while IFS= read -r f; do
    [ -n "$f" ] && purge "$f"
  done < <(git diff --name-only ORIG_HEAD HEAD || true)
fi

echo "==> 完成：小程序端下拉刷新即可拿到最新数据"
