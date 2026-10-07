# 阿里云部署 SOP v1.0

**关联**: [[01_技术架构]] · [[02_20周路径]]
**状态**: 等 Joker 启动 (本周 P0)
**最长卡点**: ICP 备案 (15-20 天审批)

---

## 🚦 总流程 (3 阶段)

```
Phase A · 账号/域名/备案 (本周)
    1. 阿里云账号 + 营业执照实名认证
    2. 注册 jokeragent.cn + 域名实名
    3. 提交 ICP 备案 (审批 15-20 天)
       ↓ 备案审批期间...
Phase B · 服务器准备 (备案最后 3-5 天并行)
    4. 购买 ECS 2C4G + 安全组配置
    5. 初始化 Ubuntu 22.04 + SSH key
    6. 装 Docker + docker-compose
    7. Let's Encrypt SSL 证书 (备案号 → DNS 解析)
       ↓
Phase C · 应用部署 (W4 Phase 1 完成时)
    8. PostgreSQL + Redis 起 (docker-compose)
    9. clone GitHub repo + 装依赖
    10. systemd 服务化 (FastAPI + APScheduler 独立进程)
    11. nginx 反代 + HTTPS + 限速
    12. Sentry / UptimeRobot 监控接入
    13. 一键部署 + 备份脚本
```

---

## 📋 Phase A · 账号/域名/备案 (Joker 本周必做)

### A1 · 阿里云账号 (10 min)

1. 打开 https://aliyun.com
2. 注册账号 (推荐用主用手机号 + 邮箱)
3. **实名认证**: 选"企业实名" (用乔克交易社营业执照)
   - 上传营业执照
   - 法人身份证
   - 对公账户验证 (扫一笔 1 分钱)
4. 实名通过 → 账号正常 (24h 内)

> ⚠️ 个人实名也能用, 但**微信支付商户号要求**对应主体, 所以阿里云**必须企业实名**, 主体一致才能后期联通.

### A2 · 域名 jokeragent.cn (30 min)

1. 阿里云控制台 → 域名 → 注册域名
2. 搜索 `jokeragent.cn` → 直接下单 (¥55-70/年, 注册商选阿里云, 不要 Godaddy)
3. **域名信息**:
   - 持有者: 乔克交易社 (企业)
   - 联系人: 你
   - 邮箱: 注册用的
4. 提交 → **域名实名认证** (5 min, 上传营业执照 + 法人身份证, 1-3 工作日)

> ⚠️ 域名实名**没通过, 不能进入 ICP 备案**. 必须等域名实名状态 = "已审核".

### A3 · ICP 备案 (30 min 提交, 15-20 天审批) ⏰ 最紧迫

#### 准备材料 (一次性收齐)
- [x] 营业执照彩色照
- [x] 法人身份证正反面彩照
- [x] 阿里云核验单 (在线生成 + 法人签字 + 公司公章)
- [x] 网站负责人手持身份证视频 (3-5 秒, 阿里云 APP 录)
- [x] 网站名称 (建议: "乔克 AI 工具" / "乔克 AI 助手", **不出现"金融/投资/股票"字样**)
- [x] 网站内容描述: "AI 数据分析工具, 帮助用户整理 Excel 数据"
- [x] 阿里云服务器 (备案要绑 ECS, 但 ECS 还没买? 阿里云有"备案专用资源", 免费用)

#### 提交流程
1. 阿里云控制台 → 域名 → 备案 → "开始备案"
2. 选 "新增网站" (首次备案)
3. 填:
   - 主办者: 乔克交易社
   - 网站名: 乔克 AI 工具
   - 网站内容: 工具类 (不勾"金融/投资类")
   - 域名: jokeragent.cn (自动检测)
   - 服务器: 选"备案专用资源" (免费用 30 天, 给你时间买正式 ECS)
4. 上传 5 份材料
5. 阿里云审核 (1-3 天) → 提交工信部 → 工信部审核 (10-15 天)
6. 通过后收到备案号: `沪ICP备2026XXXXXXX号` (沪 = 上海, 看公司注册地)

#### 关键填写注意
| 字段 | 写法 | 原因 |
|---|---|---|
| 网站名 | "乔克 AI 工具" | **不要带"金融/股票/投资"** 否则被拒 |
| 网站内容 | "工具/数据查询" | 金融类需要持牌, 我们没牌 |
| 网站负责人 | 你本人 | 法人也可以, 看公司情况 |
| 服务器位置 | 国内 (杭州/北京/上海) | 不能海外 |

#### 备案被拒怎么办
常见原因 + 应对:
- "网站名含敏感词" → 改成纯"工具/查询/助手"类
- "未实名" → 等域名实名完成
- "材料模糊" → 重拍, 4K 分辨率
- "公司名跟营业执照不一致" → 阿里云账号实名信息 = 营业执照

---

## 📋 Phase B · 服务器准备 (备案中后期并行, W3 启动)

### B1 · 购买 ECS

**推荐配置 (MVP 阶段)**:
```
实例: ecs.t6-c1m2.large (2 核 4 GB)
镜像: Ubuntu 22.04 LTS 64位
系统盘: 40 GB SSD (云盘 ESSD PL0, ¥7/月)
带宽: 5 Mbps 按带宽计费
地域: 华东 1 (杭州) 或 华北 2 (北京)
购买时长: 1 年 (有 9 折)
价格: ~¥80-100/月
```

**升级路径**:
- 50 付费用户 → 4C8G + RDS PostgreSQL (¥200/月)
- 200 付费用户 → 8C16G + 主备 RDS (¥500/月)

### B2 · 安全组配置 (火墙)

只开放必要端口:
| 端口 | 协议 | 用途 |
|---|---|---|
| 22 | TCP | SSH (限你 IP) |
| 80 | TCP | HTTP (nginx 跳转 HTTPS) |
| 443 | TCP | HTTPS |
| 8000 | TCP | FastAPI (仅内网, 不对外) |
| 5432 | TCP | PostgreSQL (仅本机) |
| 6379 | TCP | Redis (仅本机) |

### B3 · SSH 初始化

```bash
# 我会用 SSH key 连 (你创建实例时勾选 SSH key 或后期配置)
ssh -i ~/.ssh/aliyun_key root@<ECS_IP>

# 改 root 密码 (留个备份)
passwd

# 装基础工具
apt update && apt install -y \
    curl wget git vim htop \
    build-essential python3.11 python3-pip \
    docker.io docker-compose \
    nginx certbot python3-certbot-nginx

# 装 systemd 服务管理 (已自带)
systemctl --version
```

### B4 · 域名 DNS 解析

备案通过后:
1. 阿里云控制台 → 域名 → 解析
2. 加 4 条记录:
   - `jokeragent.cn` A 记录 → ECS 公网 IP
   - `www.jokeragent.cn` A 记录 → ECS 公网 IP
   - `api.jokeragent.cn` A 记录 → ECS 公网 IP (中转 API)
   - `app.jokeragent.cn` A 记录 → ECS 公网 IP (小程序官网)

### B5 · SSL 证书

```bash
# Let's Encrypt 免费 SSL (90 天自动续)
certbot --nginx -d api.jokeragent.cn -d app.jokeragent.cn -d jokeragent.cn -d www.jokeragent.cn
# 自动改 nginx + 自动续期 systemd timer
```

---

## 📋 Phase C · 应用部署 (W4 Phase 1 完成时, 我执行)

### C1 · 一键部署脚本 (我会写)

```bash
# deploy.sh
#!/bin/bash
set -e

cd /opt/jokeragent
git pull origin main

# 1. 起数据库 (首次)
docker-compose up -d postgres redis
sleep 5

# 2. 装 Python 依赖
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 3. DB 迁移
alembic upgrade head

# 4. 跑测试 (生产部署前必跑)
pytest --cov=api --cov-fail-under=70

# 5. 重启 systemd 服务
sudo systemctl restart jokeragent-api
sudo systemctl restart jokeragent-scheduler  # 独立进程, DeepSeek #3 建议

# 6. 健康检查
sleep 3
curl -f http://localhost:8000/health || (echo "❌ 健康检查失败" && exit 1)

echo "✅ 部署完成"
```

### C2 · systemd 服务 (生产化)

```ini
# /etc/systemd/system/jokeragent-api.service
[Unit]
Description=Joker Agent FastAPI
After=network.target docker.service

[Service]
User=root
WorkingDirectory=/opt/jokeragent
EnvironmentFile=/opt/jokeragent/.env
ExecStart=/opt/jokeragent/.venv/bin/uvicorn api.main:app \
    --host 127.0.0.1 \
    --port 8000 \
    --workers 4 \
    --proxy-headers
Restart=always
RestartSec=5
StandardOutput=append:/var/log/jokeragent/api.log
StandardError=append:/var/log/jokeragent/api-err.log

[Install]
WantedBy=multi-user.target
```

```ini
# /etc/systemd/system/jokeragent-scheduler.service
# APScheduler 独立进程 (DeepSeek #3 SPOF 修复)
[Unit]
Description=Joker Agent Scheduler (Alerts)
After=network.target docker.service jokeragent-api.service

[Service]
User=root
WorkingDirectory=/opt/jokeragent
EnvironmentFile=/opt/jokeragent/.env
ExecStart=/opt/jokeragent/.venv/bin/python -m api.scheduler
Restart=always
RestartSec=5
StandardOutput=append:/var/log/jokeragent/scheduler.log

[Install]
WantedBy=multi-user.target
```

### C3 · nginx 反代

```nginx
# /etc/nginx/sites-available/api.jokeragent.cn
server {
    listen 443 ssl http2;
    server_name api.jokeragent.cn;

    ssl_certificate /etc/letsencrypt/live/api.jokeragent.cn/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.jokeragent.cn/privkey.pem;

    # 限速 (CC 防护)
    limit_req_zone $binary_remote_addr zone=apilimit:10m rate=10r/s;
    limit_req zone=apilimit burst=20 nodelay;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
    }
}
```

### C4 · 备份策略

```bash
# /opt/jokeragent/backup.sh (cron 每天 03:00)
#!/bin/bash
DATE=$(date +%Y%m%d)
BACKUP_DIR=/opt/backups
mkdir -p $BACKUP_DIR

# PostgreSQL
docker exec joker_pg pg_dump -U joker joker | gzip > $BACKUP_DIR/pg_$DATE.sql.gz

# Redis (RDB 自动落盘, 复制最新的)
cp /var/lib/docker/volumes/joker_redis_data/_data/dump.rdb $BACKUP_DIR/redis_$DATE.rdb

# OSS 异地 (用 ossutil 上传)
ossutil cp -r $BACKUP_DIR/ oss://joker-backups/$(date +%Y/%m)/

# 本地保留 7 天
find $BACKUP_DIR -mtime +7 -delete
```

### C5 · 监控接入

| 服务 | 工具 | 配置 |
|---|---|---|
| Python 异常 | Sentry | `.env` 加 `SENTRY_DSN` 自动起 |
| API 健康 | UptimeRobot | 加 `https://api.jokeragent.cn/health` 5min 一次 |
| 服务器资源 | 阿里云云监控 | 自带, 配警报: CPU > 80% / 磁盘 > 90% 推钉钉 |
| 日志查询 | journalctl | `journalctl -u jokeragent-api -f` |

### C6 · 压力测试 (上线前必做)

```bash
# Locust 模拟 100 并发 / 10 分钟
pip install locust
locust -f tests/locust_perf.py --host=https://api.jokeragent.cn \
    --users 100 --spawn-rate 10 --run-time 10m
```

**验收**:
- 响应时间 P95 < 2 秒
- 错误率 < 0.1%
- CPU < 70% / 内存 < 80% / DB 连接 < 50

如果跑炸了, **不要上线**, 先优化.

---

## 💰 完整月度成本表

| 项 | MVP (0-50 用户) | 中期 (50-200) | 规模 (200+) |
|---|---|---|---|
| 阿里云 ECS | ¥80 | ¥200 | ¥500 |
| 带宽 | ¥30 | ¥80 | ¥150 |
| 域名 | ¥6 (60/年摊销) | ¥6 | ¥6 |
| SSL | ¥0 (Let's Encrypt) | ¥0 | ¥0 |
| RDS | ¥0 (自建) | ¥200 (主) | ¥600 (主备) |
| OSS | ¥10 | ¥30 | ¥100 |
| Sentry | ¥0 (免费) | ¥0 | ¥200 (Team) |
| DeepSeek API | ¥30 (50 用户 × ¥0.6) | ¥120 | ¥500 |
| **合计** | **~¥156** | **~¥636** | **~¥2056** |

**MVP 月成本 ¥156, 你 1 个 ¥299/月付费用户就完全覆盖**. 这是 SaaS 的甜.

---

## 🚦 应急预案

| 故障 | 响应 |
|---|---|
| ECS 挂 | 自动重启 (systemd Restart=always), Sentry 推送, UptimeRobot 告警 → 5 分钟内人工介入 |
| PostgreSQL 挂 | docker-compose restart, 如数据损坏 → 从备份恢复 (最多丢 24h 数据) |
| Redis 挂 | docker-compose restart, 配额数据短暂丢失, 影响小 (AOF 持久化恢复) |
| DeepSeek 限流/挂 | 自动 fallback 到 Gemini (test 已验证) |
| 阿里云大面积故障 | 框架支持纯线下卖 (个人微信收款 + 手工发码), 业务不中断 |
| 备案被吊销 | DNS 切到海外节点 (但用户在国内访问会慢), 同时申诉 |

---

## 📚 关联资源

- 阿里云备案文档: https://help.aliyun.com/product/35468.html
- Let's Encrypt: https://letsencrypt.org/zh-cn/
- nginx 配置最佳实践: https://github.com/h5bp/server-configs-nginx
- systemd Cheat Sheet: https://wiki.archlinux.org/title/systemd
