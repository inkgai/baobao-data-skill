---
name: baobao-data-skill
description: 只读查询爆爆数据（data.inkgai.com）的公众号、头条号爆文，小红书爆款笔记与历史榜单快照，订阅文章、热点热榜和收藏选题。用于找选题素材、按日期或分类看爆款、比较互动指标、查看笔记详情；无需用户明确提到 API。写文章或修改订阅、收藏不属于此技能。
---

# 爆爆数据 · 选题素材

所有接口都是只读的 GET，统一用 `scripts/bb.sh` 调用。以下命令从当前 Skill 的安装目录执行（即本 `SKILL.md` 所在目录），不要假定固定的工具或安装路径：

```bash
S=./scripts/bb.sh
"$S" '/v1/articles?platform=wx&order_by=read_num&page_size=20'
```

## 鉴权（第一次用先检查）

`bb.sh` 读环境变量 `BAOBAO_DATA_API_KEY`（兼容旧名 `MONAO_API_KEY`）。如果返回 `NO_KEY`：

1. 让用户打开 https://sso.inkgai.com/home/apikey 登录，创建或复制一把 `ak_...` 开头的 key
2. 让用户在 `~/.zshrc` 里加 `export BAOBAO_DATA_API_KEY=ak_...`，然后 `source ~/.zshrc`

不要让用户把 key 贴进对话，也不要把 key 拼进 URL。

公开 `/v1/*` API 要求有效会员，管理员 key 豁免；非会员包括第一页也会返回 `MEMBERSHIP_REQUIRED`。公众号、头条和小红书列表及详情需要 `posts:read`，订阅/收藏需要 `feed:read`，搜索/热榜需要 `search:read`。GET 对应的 HEAD 也受同一权限约束。

普通会员响应不含文章全文；`has_content=true` 只说明库中存在正文，不表示 API 会返回。小红书详情本身只含简介与榜单快照，任何身份都没有笔记全文。

**中文参数必须先 URL 编码**：`q=$(jq -rn --arg v 'AI 创业' '$v|@uri')`。

## 按用户意图选查询

| 用户想要 | 接口 |
|---|---|
| 公众号爆文（10w+、低粉爆文、按赛道） | `/v1/articles?platform=wx` |
| 头条号爆文 | `/v1/articles?platform=toutiao` |
| 小红书爆款笔记、分类榜、历史榜单 | `/v1/xhs/viral-notes`，先读 [小红书查询说明](references/xiaohongshu.md) |
| 小红书笔记详情 | `/v1/xhs/viral-notes/:id`，保留列表的日期、轮次、分类 |
| 按话题搜公众号爆文（相关度排序） | `/v1/search?q=…` |
| 我订阅的号最近发了啥 / 我订阅了哪些号 | `/v1/feed`、`/v1/feed/sources` |
| 热点热榜 | `/v1/hot-rank/overview`、`/v1/hot-rank?channel_id=` |
| 我的收藏选题 | `/v1/topics` |
| 公众号/头条文章详情 | `/v1/posts?ids=…`（批量）、`/v1/articles/:id`；正文受权限限制 |

### 1 + 2. 爆文库：`/v1/articles`

公众号、头条号用同一个接口，只差 `platform`。

| 参数 | 取值 |
|---|---|
| `platform` | `wx` 公众号 / `toutiao` 头条号 |
| `viral_type` | `10w_plus`（10 万+）/ `low_fans`（低粉爆文，**只有公众号支持**，头条号传了会报 400） |
| `category` | 赛道码，公众号用拼音（`keji` 科技、`yuer` 育儿、`caijing` 财经…），头条号用数字码；完整表见 `references/categories.md` |
| `q` | 标题关键词（模糊匹配） |
| `min_read` | 最低阅读数 |
| `from` / `to` | 发布时间范围，如 `2026-09-24`（ISO 日期） |
| `order_by` | `published_at`（默认，最新）/ `read_num`（阅读最高）/ `hotness`（热度） |
| `page` / `page_size` | 默认 1 / 20。开放 API 仅会员可用，分页还受服务端上限和限流约束 |

```bash
# 近 7 天科技赛道公众号阅读最高的 10w+
$S "/v1/articles?platform=wx&category=keji&viral_type=10w_plus&order_by=read_num&from=$(date -v-7d +%F)"
# 头条号最新爆文，标题含「育儿」
$S "/v1/articles?platform=toutiao&q=$(jq -rn --arg v '育儿' '$v|@uri')"
```

返回字段：`id`、`platform`、`title`、`nickname`（号名）、`category`、`content_url`、`published_at`、`read_num`、`like_num`、`share_num`、`comment_count`、`hotness`、`is_10w_plus`、`is_low_fans`。普通会员不返回 `content`；管理员可能收到正文，浏览列表可用 `| jq '.data |= map(del(.content))'` 精简。

### 小红书爆款笔记：`/v1/xhs/viral-notes`

```bash
"$S" '/v1/xhs/viral-notes?order_by=interactive&page_size=10'
```

默认展示最新有数据的榜单日期及该日最近有数据的轮次。支持日期、25 个已配置分类、标题/简介/作者关键词，以及本期新增互动、收藏、点赞排序。省略分类表示跨分类去重；`category=综合全部` 只查一个综合榜。小红书笔记榜与 `/v1/hot-rank?channel_id=8` 热搜榜是不同数据。

读 [references/xiaohongshu.md](references/xiaohongshu.md) 后再做分类、历史日期、指标解读和详情查询。展示榜单日期与本期新增指标；没有阅读量，简介不能当作全文。

### 公众号话题搜索：`/v1/search`

用户给的是一个话题而不是赛道（「AI 创业」「大厂裁员」）时，用它比 `/v1/articles?q=` 更准，按相关度排序，**只覆盖公众号**。

参数：`q`（必填）、`since`（`today` / `7d` 默认 / `30d` / `all`）、`scope`（`hot` 爆文池，默认 / `subscribed` 我订阅的 / `all`）、`min_read`、`sort`（`relevance` / `published_at` / `read_num`）、`page_size`（最多 50）。

返回多了 `score`（0–10）和 `matched` 命中明细。

### 3. 我的订阅：`/v1/feed`、`/v1/feed/sources`

```bash
$S '/v1/feed/sources'                                   # 我订阅了哪些号
$S '/v1/feed?range=7d&sort=read_num&page_size=20'       # 订阅号近 7 天文章，按阅读排
```

`/v1/feed` 参数：`range`（`today` / `7d` / `30d` / `all`）、`wxid`（只看某个号）、`q`（标题关键词）、`sort`（`published_at` / `read_num`）、`page` / `page_size`（最多 50）。
返回：`title`、`author.name`、`url`、`published_at`、`metrics.read/like/share`、`has_content`。

### 4. 热点：`/v1/hot-rank`

```bash
$S '/v1/hot-rank/overview'          # 30 个榜单各取前 3，适合「今天有什么热点」
$S '/v1/hot-rank?channel_id=1'      # 某个榜的最新完整一批
$S "/v1/hot-rank/trend?channel_id=1&hours=24&title=$(jq -rn --arg v '某热搜' '$v|@uri')"   # 某条热搜 24h 走势
```

常用 `channel_id`：1 微博、2 知乎、3 百度、4 抖音、5 今日头条、7 B 站、8 小红书、10 腾讯新闻、19 澎湃、27 36氪、28 虎嗅、31 IT之家。完整列表：`$S '/v1/hot-rank/channels'`。
返回：`title`、`url`、`hot`（热度值，可能为 null）、`hot_tag`、`rank_no`、`snapshot_at`。overview 里 `status=unavailable` 表示该榜这次没采到，跳过即可。

### 5. 我的收藏选题：`/v1/topics`

```bash
$S '/v1/topics?status=idea&page_size=50'
```

参数：`status`（`idea` 想法 / `planned` 已排期 / `writing` 写作中 / `published` 已发布 / `archived` 归档）、`platform`（`wx` / `toutiao` / `xhs`）、`q`、`page` / `page_size`（最多 100）。
返回：`title`、`angle`（切入角度）、`notes`、`status`、`platform`，以及来源爆文 `source_title` / `source_url` / `source_nickname` / `source_read_num`；`meta.counts` 是各状态的数量。

小红书来源没有阅读量，不能把 `source_read_num` 当作真实阅读数；互动指标和榜单快照需查小红书专用接口。

只读。用户要新增、改状态、删除选题，让他去 https://data.inkgai.com/topics 操作。

### 公众号/头条文章详情

```bash
$S '/v1/posts?ids=12,34,56'     # 最多 50 个，按入参顺序返回，找不到的放进 missing_ids
$S '/v1/articles/12345'         # 单篇爆文详情，正文受权限限制
```

普通会员用元数据、摘要和原文链接交接素材；只有响应实际包含 `content` 时才能使用正文。小红书 ID 不用于这些文章详情接口，应走专用笔记详情并保留快照身份。

## 选题素材的标准流程

用户说「帮我找几个 X 方向的选题 / 素材」时：

1. 按用户指定的平台和时间范围查询；未指定时选相关素材库。小红书用专用笔记接口，公众号话题用 `/v1/search`，订阅用 `/v1/feed`，热搜用 `/v1/hot-rank`。
2. 用户需要避免重复选题时，查 `/v1/topics` 并标出已收藏项目。
3. 提炼候选的标题、平台/作者、该平台真实提供的指标、日期、原文链接及推荐理由。
4. 用户选定后取对应详情。小红书交接简介、快照指标与原文链接；文章正文仅在响应有该字段时交给写作流程。

## 输出要求

- 不要把 JSON 原样贴给用户，整理成编号列表或表格
- 阅读数可写成「10w+」「3.2w」；小红书保留指标原值及近似/下界含义，不补阅读量。榜单日期写准确日期，和发布时间、获取时间区分
- 每条都附上原文链接
- 结果为空时可放宽关键词或分类再查一次，并说明调整。用户指定的历史日期不要静默替换；小红书空结果先结合 `meta.status`、分类状态和 `available_dates` 判断

## 错误码

`bb.sh` 保留服务端错误 JSON，HTTP 错误不一定对应非零脚本退出码；读取 `error.code` 判断结果，不会自动重试请求。

| 状态码 / code | 处理 |
|---|---|
| `NO_KEY` | 按上面「鉴权」引导用户配置 |
| 401 `UNAUTHORIZED` | key 无效或缺失，让用户到 SSO 检查 key |
| 403 `INSUFFICIENT_SCOPE` / `FORBIDDEN` | key 权限不够或账号停用 |
| 403 `MEMBERSHIP_REQUIRED` | 开放 API 要求会员，提示开通：https://data.inkgai.com/membership |
| 400 `BAD_QUERY` / `UNSUPPORTED_LOW_FANS_PLATFORM` | 参数错，看 message 改 |
| 400 `PAGE_TOO_DEEP` | 用日期、分类或关键词缩小范围，不继续加页码 |
| 404 `NOT_FOUND` | 跳过这条 |
| 404 `Route GET:/v1/... not found` | 服务端还没部署这个接口，告诉用户 |
| 405 `METHOD_NOT_ALLOWED` | 发了写请求，本 skill 只读 |
| 429 / 503（包括 `MEMBERSHIP_UNAVAILABLE`） | 尊重 Retry-After 或错误提示，稍后最多重试 2 次；仍失败则报告，不能绕过权限或限制 |
