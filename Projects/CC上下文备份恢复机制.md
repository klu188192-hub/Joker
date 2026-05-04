# CC 上下文备份与恢复机制

> 适用于所有 CC 实例（Joker / VV / TT 等），防止上下文满溢后丢失进度。

## 背景

CC 使用 1M context 模型时，`/compact` 需要额外付费权限，满了只能 `/clear`。
本机制让 CC 主动备份，`/clear` 后 30 秒内恢复进度。

---

## 已配置的自动机制

| 触发时机 | 钩子 | 行为 |
|---|---|---|
| 每 20 次工具调用 | `PostToolUse → context_guard.py` | CC 收到 additionalContext 提醒，立即写备份 |
| 上下文即将压缩 | `PreCompact hook` | 强制提醒先写备份再压缩 |
| 会话结束 | `Stop hook` | 写 `_last_session_end.txt` 时间戳 |

**相关文件：**
- 钩子脚本：`/Users/joker/.claude/scripts/context_guard.py`
- 备份目录：`/Users/joker/.claude/session_backups/`
- 全局规则：`/Users/joker/.claude/CLAUDE.md`（末尾"上下文备份与恢复"节）

---

## 备份格式

CC 写到 `/Users/joker/.claude/session_backups/<任务名>_latest.md`，例如：
- `wecom_latest.md`（企微 Joker 助手）
- `factor_latest.md`（量化因子库）
- `copier_latest.md`（MT5 跟单系统）

```yaml
task: wecom图表优化
time: 2026-05-04T18:00:00
goal: 企微 Joker 助手图表与样图风格一致
done:
  - v10 白底 SMC 自动识别已部署
  - 推送 XAU H4 + BTC H1 样图到企微
current: K线不居中，格式差距大
next: 按用户样图继续调整 render_chart_image，重点：K线居中+间距
files:
  - /path/to/wecom_bridge.py — 主进程
  - kk:C:\Tools\wecom-bridge\tt_modules\smc_detector.py — SMC 检测
env:
  server: kk-win
```

---

## 恢复流程（/clear 后操作）

### 1. 列出现有备份
```
ls /Users/joker/.claude/session_backups/
```

### 2. 读取对应备份
```
Read /Users/joker/.claude/session_backups/wecom_latest.md
```

### 3. 从 `next` 字段继续
不需要用户重新解释背景，直接执行 next 指定的动作。

---

## Joker CC 企微任务恢复（当前状态）

```
/clear
```
然后发：
```
Read /Users/joker/.claude/session_backups/wecom_latest.md
```
若备份不存在，直接告知：
> 你在做企微 Joker 助手图表风格优化（v10），白底 SMC 自动识别已上线。  
> 问题：K线不居中，整体格式离样图差距大。  
> 继续改 `render_chart_image`，重点对齐 K线居中 + 间距 + 颜色。  
> 样图在 `kk:C:\Tools\wecom-bridge\user_style_manual.md`。

---

## 注意事项

- `/compact` 在 1M context 下需要额外付费 → 不依赖它
- 切到 Sonnet 后 `/compact` 仍可能失败（context 已超 Sonnet 上限）
- 唯一保险：**提前备份 + /clear + Read 恢复**
- context_guard 每 20 次工具调用提醒一次，不要忽略
