# GitHub 开源模块清单 v1.0

**状态**: ✅ **已锁定 (Joker 同意推荐组合 · 2026-05-30)**
**关联**: [[00_产品总览]] · [[01_技术架构]]

**最终决议**: 按本文档底部"我推荐的最终组合"全部接入, 已写入 `~/jokeragent/requirements.txt`. 后续如需增减, 在此文档加 changelog 即可.

---

## 🎯 数据源类 (A 股, 必选 2-3 个做容灾)

| 选   | 模块                | Star  | 用途                      | 价格                          | 优势        | 劣势                |
| --- | ----------------- | ----- | ----------------------- | --------------------------- | --------- | ----------------- |
| ⬜   | **akshare**       | 9.9k  | A 股全市场数据 (实时/历史/财报/龙虎榜) | 免费                          | 覆盖广       | 爬虫, 15min 延迟, 偶尔挂 |
| ⬜   | **tushare**       | 4.6k  | A 股标准化数据                | 免费 2000 积分 / 付费 ¥500-2000/年 | 商用合规 ✅    | 免费版限频             |
| ⬜   | **easyquotation** | 4.1k  | 真实时行情 (新浪/腾讯)           | 免费                          | 15-30s 延迟 | 单 IP 限频, 爬虫       |
| ⬜   | **baostock**      | 2.5k  | A 股历史 + 部分实时            | 免费                          | 稳定        | 实时有限              |
| ⬜   | **efinance**      | 1.7k  | 东财数据爬取                  | 免费                          | API 简洁    | 爬虫                |
| ⬜   | yfinance          | 14.9k | 美股/港股/外汇/币圈             | 免费                          | 海外数据      | 国内访问慢             |
| ⬜   | ccxt              | 35k   | 30+ 加密货币交易所             | 免费                          | 币圈一把梭     | MVP 不需要           |
| ⬜   | OpenBB Terminal   | 30k   | 全能金融终端                  | 免费                          | 学架构       | 不直接用              |

> **我推荐组合**: `akshare` + `tushare` + `easyquotation` 三件套 (容灾)

---

## 🛠️ 技术指标 + 量化分析

| 选   | 模块                             | Star  | 用途                                     |
| --- | ------------------------------ | ----- | -------------------------------------- |
| ⬜   | **TA-Lib**                     | 10.3k | 150+ 技术指标 (MACD/RSI/布林/KDJ) · C 库, 性能强 |
| ⬜   | **stockstats**                 | 1.4k  | 纯 Python 技术指标, 装起来简单                   |
| ⬜   | pandas-ta                      | 5.3k  | TA-Lib 的 pandas 友好版                    |
| ⬜   | mplfinance                     | 3.7k  | 静态 K 线图 (matplotlib)                   |
| ⬜   | **plotly**                     | 17k   | 交互 K 线图 (zoom/hover)                   |
| ⬜   | plotly-resampler               | 1.1k  | plotly 大数据优化                           |
| ⬜   | TradingView Lightweight Charts | 9.6k  | 像 TradingView 的图表 (JS, 接小程序时用)         |
| ⬜   | finquant                       | 1.4k  | 投资组合分析                                 |
| ⬜   | backtrader                     | 15k   | 完整回测框架 (后期 Agent #4 用)                 |
| ⬜   | vectorbt                       | 5.4k  | 高性能回测                                  |

> **我推荐**: `stockstats` (装简单) + `plotly` (交互图) · 后期上 `TA-Lib` (性能)

---

## 🎨 Streamlit UI 美化 (改"丑"的关键)

| 选 | 模块 | Star | 用途 |
|---|---|---|---|
| ⬜ | **streamlit-shadcn-ui** | 700 | shadcn 风格组件, 让 UI 像专业产品 |
| ⬜ | **streamlit-extras** | 1.2k | metric 卡 / 选项卡 / 各种小组件 |
| ⬜ | **streamlit-aggrid** | 1.1k | Excel 风格数据表 (F2 交易记录展示) |
| ⬜ | **streamlit-authenticator** | 1.5k | 登录页组件 |
| ⬜ | streamlit-elements | 600 | Material UI 组件 |
| ⬜ | streamlit-option-menu | 1.1k | 侧边栏导航美化 |
| ⬜ | streamlit-lottie | 800 | Lottie 动画 (开屏 / 加载) |
| ⬜ | streamlit-chat | 1.7k | 类 ChatGPT 聊天 UI |

> **我推荐组合**: `shadcn-ui` + `extras` + `aggrid` + `chat` · 这套足够漂亮

---

## 🔐 鉴权 + 用户系统

| 选 | 模块 | Star | 用途 |
|---|---|---|---|
| ⬜ | **python-jose** | 1.6k | JWT 生成/验证 (FastAPI 标配) |
| ⬜ | **passlib** | - | 密码 hash (bcrypt) |
| ⬜ | python-multipart | - | 表单上传 |
| ⬜ | authlib | 4.7k | OAuth2 / 微信扫码登录 |

> **必选**: `python-jose` + `passlib` + `python-multipart` (FastAPI 已默认推荐)

---

## 💬 LLM + AI

| 选 | 模块 | Star | 用途 |
|---|---|---|---|
| ⬜ | **openai (SDK)** | 24k | DeepSeek 兼容 OpenAI 接口, 用这个就够 |
| ⬜ | google-generativeai | 1.9k | Gemini SDK |
| ⬜ | instructor | 9.8k | 结构化 LLM 输出 (Pydantic 验证) |
| ⬜ | marvin | 5.5k | 轻量 LLM 函数调用 |
| ❌ | LangChain | 95k | 不推荐, 太重 |
| ❌ | AutoGen | 38k | 不推荐, 我们 1 agent 1 task |
| ❌ | CrewAI | 26k | 不推荐, 过度设计 |

> **必选**: `openai` (DeepSeek) + `google-generativeai` (Gemini 备) · `instructor` 让 LLM 输出严格 JSON

---

## 📨 推送 + 通知

| 选 | 模块 | Star | 用途 |
|---|---|---|---|
| ⬜ | **wxpusher** | - | 微信推送, 免备案 |
| ⬜ | Server酱 | - | 微信推送 (备用) |
| ⬜ | **wechatpy** | 3.7k | 微信支付 + 公众号 SDK |
| ⬜ | qcloudsms_py | - | 腾讯云短信 (备用通道) |
| ⬜ | apscheduler | 6.5k | 定时任务 (警报检测) |
| ⬜ | celery | 25k | 任务队列 (大规模后用) |

> **MVP**: `wxpusher` + `apscheduler` 够用 · 100+ 用户后上 `celery`

---

## 📄 PDF + 文件处理

| 选 | 模块 | Star | 用途 |
|---|---|---|---|
| ⬜ | **WeasyPrint** | 7.9k | HTML → PDF (复用乔克交易社 v3.1 已有) |
| ⬜ | reportlab | - | 直接画 PDF (复杂排版) |
| ⬜ | **Pillow** | 12.7k | 生成分享卡片 (朋友圈) |
| ⬜ | python-docx | 4.9k | Word 文档生成 |

> **必选**: `WeasyPrint` (PDF) + `Pillow` (分享卡片)

---

## 🗄️ 数据库 + 缓存

| 选 | 模块 | Star | 用途 |
|---|---|---|---|
| ⬜ | **SQLAlchemy** | 10.3k | ORM (FastAPI 标配) |
| ⬜ | **asyncpg** | 7.5k | PostgreSQL async 驱动 |
| ⬜ | **alembic** | 3.1k | 数据库迁移 |
| ⬜ | **redis-py** | 13k | Redis Python 客户端 |
| ⬜ | tortoise-orm | 5.1k | 备选 ORM |

> **必选**: `SQLAlchemy` + `asyncpg` + `alembic` + `redis-py`

---

## 🚀 部署 + 打包

| 选 | 模块 | Star | 用途 |
|---|---|---|---|
| ⬜ | **PyInstaller** | 12.5k | 打包桌面 .exe |
| ⬜ | briefcase | 2.7k | 跨平台打包替代 |
| ⬜ | PyOxidizer | 5.8k | 更小的打包 (Rust 底层) |
| ⬜ | nuitka | 13k | Python → C++ 编译 |

> **MVP**: `PyInstaller` · 后期考虑 `nuitka` 压缩 + 性能

---

## 🧪 测试 + 质量

| 选 | 模块 | Star | 用途 |
|---|---|---|---|
| ⬜ | **pytest** | 13k | 单元测试 |
| ⬜ | **pytest-asyncio** | 1.5k | async 测试 |
| ⬜ | **pytest-cov** | 1.8k | 覆盖率 |
| ⬜ | **httpx** | 14k | FastAPI 测试客户端 |
| ⬜ | **playwright** | 71k | E2E 浏览器测试 |
| ⬜ | hypothesis | 7.7k | 属性测试 (高级) |

> **必选**: 前 5 个 · CI 跑 `pytest --cov=70`

---

## 🛡️ 监控 + 错误上报

| 选 | 模块 | Star | 用途 |
|---|---|---|---|
| ⬜ | **sentry-sdk** | 1.9k | 异常自动上报 |
| ⬜ | loguru | 21k | 漂亮的日志库 |
| ⬜ | prometheus-client | 4.1k | 指标暴露 (大规模后用) |

> **必选**: `sentry-sdk` + `loguru`

---

## ❌ 别碰 (坑/合规风险)

| 模块 | 原因 |
|---|---|
| easytrader | 自动下单, 极高合规风险 |
| 各种 "AI 量化策略" repo | 99% 是 demo, 不能商用 |
| 复杂的 Multi-Agent 框架 | 你场景不需要 |
| 任何带"必赚/暴富"字样的项目 | 合规雷 |

---

## 📋 我推荐的最终组合 (一键复制)

```python
# requirements.txt 核心 (已写在 ~/jokeragent/requirements.txt)
fastapi[all]==0.115.0
uvicorn[standard]==0.32.0
pydantic==2.9.0
pydantic-settings==2.5.0

# 数据库
sqlalchemy[asyncio]==2.0.36
asyncpg==0.30.0
alembic==1.13.3
redis==5.1.1

# 鉴权
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4

# LLM
openai==1.54.0           # DeepSeek
google-generativeai==0.8.3   # Gemini
instructor==1.6.4        # 结构化输出

# 数据源
tushare==1.4.6
akshare==1.15.0
easyquotation==0.7.6

# 技术指标
stockstats==0.6.2
mplfinance==0.12.10b0
plotly==5.24.1

# 桌面 UI
streamlit==1.39.0
streamlit-shadcn-ui==0.1.18
streamlit-extras==0.5.0
streamlit-aggrid==1.0.5
streamlit-chat==0.1.1

# PDF + 图
weasyprint==62.3
jinja2==3.1.4
Pillow==11.0.0

# 推送 + 调度
wechatpy==1.8.18
apscheduler==3.10.4
requests==2.32.3

# 测试
pytest==8.3.3
pytest-asyncio==0.24.0
pytest-cov==5.0.0
httpx==0.27.2
playwright==1.48.0

# 监控
sentry-sdk[fastapi]==2.18.0
loguru==0.7.2

# 打包
pyinstaller==6.11.0
```

---

## 🎯 待你筛选的决策

你打勾 / 反对 / 备注后, 我:
- 接受的 → 实际写到 `~/jokeragent/requirements.txt`
- 反对的 → 找替代
- 备注的 → 单独讨论
