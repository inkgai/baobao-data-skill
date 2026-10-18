# 小红书爆款笔记与榜单快照

接口：`GET /v1/xhs/viral-notes`、`GET /v1/xhs/viral-notes/:id`。SSO key 需要 `posts:read`；开放 API 要求有效会员（管理员豁免）。只读取已保存的榜单，不触发新的采集。

## 列表查询

从本 Skill 目录设置 `S=./scripts/bb.sh`。需要 curl；以下中文编码和结果处理示例还使用 jq。

| 参数 | 契约 |
|---|---|
| `rank_date` | 有效 `YYYY-MM-DD` 榜单日期；不是笔记发布时间。不支持 `from/to/since` 日期范围参数 |
| `collection_slot` | `06`、`18`、`bf`；通常省略，复现某条快照时沿用返回值 |
| `category` | 下方 25 个中文名称之一，须 URL 编码；省略表示合并所有分类后按笔记去重 |
| `q` | 最长 128 字符；标题、简介、作者名的子串匹配，忽略大小写；不是全文或相关度检索 |
| `order_by` | `interactive`（默认，本期新增互动）、`favorite`（本期新增收藏）、`like`（本期新增点赞）、`source`（来源顺序） |
| `page` / `page_size` | 默认 1 / 20；每页最多 100。受会员、限流及翻页深度限制，`PAGE_TOO_DEEP` 时缩小范围 |

未指定日期时，选最新存在成功分类的榜单日期；该日默认使用有数据的最近轮次，同日优先级 `18` → `06` → `bf`。只有空榜或待处理批次时可能返回空数据及相应状态，以实际响应为准。显式指定的日期或轮次没有数据时，不会自动切到别的日期或轮次。

```bash
# 最新有数据的榜单，所有分类去重，按本期新增互动排序
"$S" '/v1/xhs/viral-notes?order_by=interactive&page_size=10'

# 最新榜的数码科技，匹配标题、简介或作者中的 AI，按新增收藏排序
category=$(jq -rn --arg v '数码科技' '$v|@uri')
q=$(jq -rn --arg v 'AI' '$v|@uri')
"$S" "/v1/xhs/viral-notes?category=$category&q=$q&order_by=favorite&page_size=20"

# 指定榜单日期；日期仅为格式示例，查询前可查看 meta.available_dates
"$S" '/v1/xhs/viral-notes?rank_date=2026-10-13&order_by=like&page_size=20'

# 综合全部是一个分类，不等于省略 category 后的跨榜合集
category=$(jq -rn --arg v '综合全部' '$v|@uri')
"$S" "/v1/xhs/viral-notes?category=$category&order_by=source"
```

日期范围要按实际 `meta.available_dates` 选择日期逐日查询，保留每天的榜单身份；不要把同一笔记跨日计数相加称为独立笔记总量。用户仅要几条素材时，无需遍历全部日期或页数。

## 25 个已配置分类

`综合全部`、`出行代步`、`医疗保健`、`休闲爱好`、`综合杂项`、`婚庆婚礼`、`居家装修`、`影视娱乐`、`星座情感`、`拍摄记录`、`学习教育`、`旅行度假`、`亲子育儿`、`日常生活`、`科学探索`、`数码科技`、`时尚穿搭`、`化妆美容`、`个人护理`、`美味佳肴`、`职业发展`、`宠物天地`、`新闻资讯`、`体育锻炼`、`潮流鞋包`。

这些是当前服务配置的榜单范围，不代表小红书全站所有爆款。公众号拼音码、头条数字码不能用于这里。

未传分类时，同一日期和轮次中每条笔记只返回一次；优先采用综合榜快照，否则按上述分类顺序选择快照。传分类时采用该分类快照。返回 `category` 是所选快照分类，`categories` 是该笔记同日同轮命中的全部分类。`order_by=source` 在多榜合集中不是一个全站排名。

## 响应与指标

列表返回 `{data: [...], meta: {...}}`；详情返回 `{data: {...}}`。

- 笔记：`id`（服务内编号）、`source_id`（小红书笔记编号）、`title`、`summary`、`content_url`、`cover`、`author_id/name/avatar/url`、`fans`、`published_at`、`source_order`。
- 快照：`rank_date`（榜单日期）、`collection_slot`（真实轮次）、`category`、`categories`、`fetched_at`（实际获取时间）。`06`、`18` 表示北京时间早晚采集轮次；常规采集前一日榜。`bf` 表示之后执行的历史回补，不是当时早晚的采集记录。不要根据榜单日期伪造获取时间。
- `added` 和 `total` 均包含 `interactive`、`like`、`favorite`、`comment`、`share`。`added` 展示为“本期新增”，来源尚未确认具体统计窗口，不能改称“今日新增”或“24 小时新增”；`total` 是该快照中的累计值。
- 每个指标及 `fans` 都是 `{raw, value, approximate, bound}`：优先展示原字符串 `raw`；`value` 用于计算/排序。`w/万` 可能只是近似值，`approximate=true` 不应写成精确整数；`bound=lower` 表示下界，保留 `+` 或写“至少”。`value=null` 是未知，不是 0；如果 `raw` 缺失，用 `value` 与标记表达，不捏造原值。
- 没有阅读量。`summary` 只是简介，不是完整图文或视频文案；不推断图文/视频类型。

`meta.total` 是当前日期、轮次和查询条件下的去重笔记数，未分页前计算，不能称全库总量。`meta.page/page_size` 是实际分页；`rank_date/collection_slot` 是当前榜单；`last_fetched_at` 是本轮成功记录中最近获取时间。`available_dates` 也可能包含空榜、失败或待处理日期，不保证每个日期都有笔记。

`meta.categories` 列出 25 类各自的 `status/item_count/last_attempt_at`（可能含 `error`）：`complete` 已获取、`source_empty` 来源为空、`pending` 待处理、`failed` 失败。总状态 `complete` 表示全部成功，`partial` 表示部分分类成功，`empty` 表示没有成功分类但存在来源空榜，`pending` 表示尚无成功/空榜结果。即使总状态完整，关键词也可能匹配不到笔记。分类条数相加可能重复，不用于计算去重总量。

## 详情必须保留快照身份

列表里的同一个 `id` 可以出现在多个日期、轮次或分类。进入详情时同时传这条记录的 `rank_date`、`collection_slot`、`category`，避免看到另一期数据。不要用文章 `/v1/posts` 或 `/v1/articles` 代替此接口。

```bash
# 从实际列表行生成详情路径；中文分类由 jq 编码，保留 bf 等真实轮次
result=$("$S" '/v1/xhs/viral-notes?page_size=10')
detail_path=$(printf '%s' "$result" | jq -r '
  .data[0] // empty |
  "/v1/xhs/viral-notes/\(.id)?rank_date=\(.rank_date)&collection_slot=\(.collection_slot)&category=\(.category | @uri)"
')
if [ -n "$detail_path" ]; then
  "$S" "$detail_path"
fi
```

详情未传日期时，查该笔记最近存在的成功快照（可受分类/轮次筛选）；传日期但未传轮次时，采用该日期默认轮次，该笔记不在那一轮可能返回 404。指定快照不存在返回 `NOT_FOUND`，不能静默改成最新版后仍标注旧日期。

输出可包含标题、作者、榜单日期、本期新增互动/收藏/点赞、累计指标和原文链接。历史比较要标出各快照真实身份；没有完整正文时，明确交接的是简介与数据素材。
