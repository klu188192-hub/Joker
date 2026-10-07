# XAUUSD 量化策略 — 项目主入口

> ## 🔴🔴🔴 第一原则铁律 (优先级 0, 不可破)
>
> **4 个 EBC 实盘账户 = $54,198 USD, 全跑黑龙, 任何场景完全不可碰**:
>
> | 账户 | install | 余额 |
> |---|---|---:|
> | EBC **6506031** | `D:\EBC-4\` | $30,000 |
> | EBC **6507573** | `D:\EBC-5\` | $13,569 |
> | EBC **6531330** | `D:\EBC-6\` | $8,029 |
> | EBC **6531399** | `D:\EBC-7\` | $2,600 |
>
> 禁止操作:
> - ❌ 不杀进程 (Stop-Process terminal64)
> - ❌ 不做测试 (ShutdownTerminal=1 严禁)
> - ❌ 不擅自打开/关闭 MT5
> - ❌ 不 deploy ex5 / 不改 INI / 不改 chart / 不写文件到 D:\EBC-4/5/6/7
> - ✅ **唯一允许**: Joker 明令"放 EA 文件 X 到 D:\EBC-N 目录" — 仅复制, 不启动
>
> 每次 ssh kk 命令前必须自检 path 不属于 D:\EBC-4/5/6/7. 详见 [[memory:feedback_ebc_real_accounts_inviolable.md]]
>
> ---
>
> ## 🔴 Claude 强制行为 (新会话第一件事必做)
>
> 1. **读本文件** (5 分钟全貌)
> 2. **读 [[10-Claude每日同步规则]]** — 强制 SOP, 不可跳过
> 3. **读 `日志/<最近日期>.md`** (按时间倒序最近的) — 上次工作 + Open Threads
> 4. **读 [[05-下一步行动]]** — backlog
>
> **不要直接开始工作**. 用户不会每次提醒, Claude 自己负责.
> **工作结束必须写当天日志 + 更新影响的文档** (见 [[10-Claude每日同步规则]] 的 checklist).
> 新会话第一句应该是: "已读 00-INDEX + 日志/<日期> + 05-下一步. 当前优先级是 X (来自 Open Threads). 我从 X 开始, 除非你要换方向."

**项目**: SignalDriven_MasterCombo 系列 EA / XAUUSD H1 MQL5
**主开发机**: KK (DESKTOP-7F59OEJ, Win11) — Tailscale `kk` / LAN `kk-lan` (192.168.11.7)
**测试 install**: `D:\IC-tester\` (账户 52872396 ICMarketsSC-Demo)
**主 demo 不可动**: `D:\新建文件夹\` + `D:\EBC-mt5\` (按 [[01-工作原则与铁律#不可动 demo 路径]])
**最近更新**: 2026-05-25 (下午段加 watchdog/healthcheck/backup + EA 改名 v8_paper)
**当前会话产出归档**: [[日志/2026-05-25]] (paper test 启动 + 15:24 重启 + 守护层完工) | [[03-V8完整审计_20260524]] (审计历史)

---

## 当前状态快照 (2026-05-24)

| 维度 | 状态 |
|---|---|
| **当前 production lock 版本** | **v8 (lock 5/22, 审计后 v8 系列已触顶, paper test 用 lock 原配置)** |
| **lock 配置 archive** | `~/factor_factory_archive/v20260522_v8_cutM2_production/` |
| **lock 配置 INI** | `D:\IC-tester\config\v8_production_22m_raw.ini` |
| **EA 源码 (原)** | `D:\IC-tester\MQL5\Experts\SignalDriven_MasterCombo_RuleRegime_v7_BBConfl_I1_3pct.mq5` |
| **EA 源码 (paper 用, idle + reload + 简化名)** | `D:\新建文件夹\MQL5\Experts\v8_paper.mq5/.ex5` (1312 行 / 90754B / 编译 OK 5/25 下午) |
| **EA 输入** | `D:\v8_paper_IdleBuffer20K.set` |
| **DeepSeek 评分** | 8/10 过拟合风险, 否决 lock production decision |
| **真 OOS 验证结果** | -$4,889 / Sharpe -0.73 / MDD 77% (跨 regime, 用户判定无效) |
| **新 regime A/B 段验证** | A Sharpe 1.46, B 4.17 (新 regime 内但 B 段 cherry-pick) |
| **22M 内 6 段一致性** | Sharpe 离散 25× (0.32-7.96), lock 配置严重不稳 (S6 拉高了 IS) |
| **DDscale sweep 触顶** | SuperLoose (MDD 45.51%) 是 backtest 极限, 但 sweep 不可信 |
| **🚀 Paper test 真正干净起点 = 5/25 18:39:27** | 之前 5h+ 是错配置 (源码 default 12 处错). 18:39 重 attach 11 处 lock 全验证. baseline $34,358.57 |
| **守护层 (5/25 下午装)** | `V8PaperWatchdog` 3min 重启 / `V8DailyBackup` 23:50 备份 / `v8_healthcheck.ps1` 一键报表 |
| **预期 forward Sharpe** | **1.0-1.5** (按 22M 6 段下限估算, 不是 IS 看到的 1.98+) |
| **第一笔 trade lot 期望** | 0.30-0.50 (按 effective $14K base) — 等待中 |

---

## 关键决定记录

1. **HMM 已弃用 (v7 起)** — EA 改用 rule-based regime (iADX + iATR + iMA 实时, 无训练数据). 用户对 HMM 黑箱训练有顾虑且已被 EA 替换. 详见 [[02-EA演进史_V1_V8#v7 改动]]
2. **`DisableRegimeFilter=true` lock 决定** — 用户即使对 rule-based regime 也保守, 关掉让所有因子无差别开仓. 风险: chop 段也开仓; 收益: 不被 regime filter 误杀
3. **N3_H1_OOS.csv 数据只覆盖 22m IS 段** — 命名误导, 这个"OOS"是 N3 generator 自己的 OOS, 不是 v8 EA 的 OOS. 真做 v8 OOS 要 RiskPct_N3=0
4. **2024.07 前的数据已失效 (用户判定)** — XAU 突破 $3000 (2025.03.17) 后 regime 完全变, 跨 regime OOS 验证无意义. 详见 [[03-V8完整审计_20260524#regime 论证据]]
5. **MDD 物理极限 ~40%** — v8 在 22m IS 内任何 DDscale tune 都砍不到 30% 以下 (不大幅损失 profit). 见 [[03-V8完整审计_20260524#DDscale sweep]]

---

## 跨机器路径快速速查

| 内容 | 位置 |
|---|---|
| **EA 源码 (v8 用)** | KK: `D:\IC-tester\MQL5\Experts\SignalDriven_MasterCombo_RuleRegime_v7_BBConfl_I1_3pct.mq5` (54897B, 5/22) |
| **测试 install** | KK: `D:\IC-tester\` |
| **CSV 信号** | KK: `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\` |
| **历史 H1 bars** | KK: `XAUUSD_H1_10y.csv` (3.4MB, 2016.05-2026.05) |
| **数据 fetch 脚本** | KK: `C:\Tools\fetch_h1_10y.py` (用 MetaTrader5 py lib copy_rates_range) |
| **factor_dev 项目** | KK: `D:\factor_dev\` (53 个因子, mac 镜像: `~/factor_dev/`) |
| **archive (mac)** | `~/factor_factory_archive/` (27 个版本) |
| **archive (KK 镜像)** | `D:\factor_factory_archive\` |
| **DeepSeek API helper** | mac: `~/.claude/scripts/ds_ask.py` |
| **memory** | mac: `~/.claude/projects/-Users-joker/memory/` |
| **factor_factory framework** | KK: `C:\Tools\factor_factory\` (含 reports/lookahead_decorator.py) |

---

## 工具命令速查

**ssh KK**:
```bash
ssh kk "powershell -NoProfile -EncodedCommand <base64>"   # 复杂命令用 base64 避引号地狱
ssh kk-lan "..."   # 局域网直连 (走 192.168.11.7)
```

**MT5 backtest 启动**:
```bash
ssh kk powershell -NoProfile -Command "Start-Process -FilePath 'D:\IC-tester\terminal64.exe' -ArgumentList '/config:D:\IC-tester\config\<NAME>.ini' -PassThru"
```
等 30-60 秒, 然后从 `D:\IC-tester\Tester\logs\<YYYYMMDD>.log` 末尾 grep `[RULEREGIME TESTER]` 拿 trades/profit/mdd/sharpe.

**EA 有 OnTester bug** (mq5 line 1122 array out of range) → HTM 不生成, 但 print 行完整可信. 不影响最终统计.

**数据下载**:
```bash
scp kk:C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files/XAUUSD_H1_10y.csv /tmp/xau_h1.csv
```

---

## Mini 状态恢复 (新 Claude 会话必读)

下次 Claude 会话开始第一件事:
1. 读本文件 (00-PROJECT_INDEX.md)
2. 读 [[03-V8完整审计_20260524]] 看今天的工作详情
3. 读 [[05-下一步行动]] 看待做事项
4. 询问用户是否启动 paper test (Loose DDscale 配置)

**不要重复跑** v8 backtest 历史段 (今天已经 6 次全跑了, 都在 [[03-V8完整审计_20260524]]).
**不要重新 audit** factor generator (今天全部 PASS, 在 [[04-因子库#审计状态]]).

---

## 文档导航

### 核心 (必读, 6 个)
| 文档 | 内容 | 何时读 |
|---|---|---|
| **本文档** (00) | 主入口, 状态快照, 跨机器路径 | **新会话第 1 个** |
| [[10-Claude每日同步规则]] | **强制 meta-SOP, Claude 行为契约** | **新会话第 2 个** ⭐ |
| **`日志/<最近日期>.md`** | 上次会话所有工作 + Open Threads | **新会话第 3 个** ⭐ |
| [[09-量化开发工作流SOP]] | **完整 11 步 SOP + 5 道防线 + checklist** | **每次决策前查** |
| [[08-犯错经验档案]] | 14 个痛史 + 6 个过拟合根源 + 反复犯错 patterns | **每次决策前查** |
| [[03-V8完整审计_20260524]] | 5/24 6 次 backtest + DDscale sweep + DeepSeek 评价 | 当前工作 |
| [[05-下一步行动]] | paper test 计划 + 三层风控 + forward 阈值 | 当前待办 |

### 资料 (查阅, 3 个)
| 文档 | 内容 |
|---|---|
| [[01-工作原则与铁律]] | CLAUDE.md 量化铁律 + ssh 引号方案 + 痛史链接 |
| [[02-EA演进史_V1_V8]] | SignalDriven_MasterCombo v1→v8 timeline + 每版改动 + EA 架构 |
| [[04-因子库]] | 53 个 factor_dev 项目 + 6 个 v8 因子详情 + audit 记录 |

**TODO 文档** (待补):
- 06-数据源与工具链 (XAUUSD H1 来源, broker 一致性)
- 07-archive路径速查 (16 个 archive 版本对照表)

---

## 关键文档的关键章节 (索引深一层)

| 找什么? | 去哪 |
|---|---|
| 为什么 v8 lock 后失败 | [[03-V8完整审计_20260524#DeepSeek-R1 评分]] |
| v8 三段 walk-forward 数字 | [[03-V8完整审计_20260524#walk-forward 三段]] |
| DDscale sweep 完整对比 | [[03-V8完整审计_20260524#DDscale sweep]] |
| 怎么防未来函数 | [[09-量化开发工作流SOP#2. 防未来函数 SOP — 详细版]] |
| 怎么防过拟合 | [[09-量化开发工作流SOP#3. 防过拟合 SOP — 详细版]] |
| OOS 段怎么选 (regime aware) | [[09-量化开发工作流SOP#C. OOS 段选择 SOP]] |
| 部署前 12 项 checklist | [[09-量化开发工作流SOP#10. 上线 checklist 一页纸]] |
| MACD/SSL 痛史 | [[08-犯错经验档案#痛史 #1]] |
| Python 失真 285× 痛史 | [[08-犯错经验档案#痛史 #2]] |
| 假 OOS 段误判痛史 | [[08-犯错经验档案#痛史 #4]] |
| 跨 regime 浪费痛史 | [[08-犯错经验档案#痛史 #5]] |
| EA 源码 RuleRegime 实现 | [[02-EA演进史_V1_V8#Rule-Based Regime Engine (line 239)]] |
| Generator → CSV 部署流程 | [[04-因子库#Generator → CSV 部署流程]] |
| ssh KK 引号地狱解决 | [[01-工作原则与铁律#ssh KK 引号地狱解决方案]] |
