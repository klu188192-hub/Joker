# 每日抖音视频生产 SOP — A 股复盘 → 短视频

> **目标**: 每个交易日 A 股复盘文章 (2000 字) → 自动产出 60-90s 抖音短视频, 引流公众号.
> **5/26 周一启动** (Joker 5/25 凌晨明令).
> **关联**: [[01_乔克交易社/07_每日内容台账]] 每日产出清单

---

## 🔴 第一原则铁律 (优先级 0)

`D:\EBC-4\` (KK) = EBC 6506031 实盘 $3 万账户, **任何 Claude 任何场景不可碰**. 详见 [[00_AI视频复刻主入口#🔴 第一原则铁律]] / `memory:feedback_ebc_6506031_real_inviolable.md`.

本 SOP 任何步骤不涉及该路径, 默认安全, 但 ssh kk 命令前仍要自检.

---

## 端到端 Pipeline

```
[16:30 KK schtasks JTC_DailyReview 自动产出]
     ↓
   ~/Marketing/乔克交易社/每日复盘自动化/复盘_M_DD.md (~2000 字)
     ↓
[Step 1] LLM 抽取核心观点 + 改写成 60-90s 短视频脚本 (8-10 段)
     工具: Doubao-pro / DeepSeek-V3
     输入: 复盘 .md 全文
     输出: JSON [{text, prompt}] × 8-10 段
     ↓
[Step 2] 每段调 Seedream 4.5 出 16:9 静态图
     model: doubao-seedream-4-5-251128
     size: 2560×1440
     成本: 8 × ¥0.09 = ¥0.72/条
     ↓
[Step 3] 每段 text 调 fish-speech (Joker 声音) → mp3
     工具: KK C:\Tools\fish-speech (5070Ti 本地)
     声纹: C:\Tools\voice_clone\joker_voice.m4a (5/22 录)
     成本: ¥0/条
     ↓
[Step 4] 字幕生成 (从 text 直接出 textfile, ffmpeg drawtext)
     字体: SourceHanSerifSC-Bold.otf (思源宋体)
     位置: 居中, 距底部 100px (规整)
     颜色: 白色 + 5px 黑描边
     ↓
[Step 5] ken burns 动效 (静态图慢推 1.0 → 1.1)
     ↓
[Step 6] ffmpeg 合成 → 1920×1080 mp4
     ↓
[Step 7] 加封面 (PIL 渲染: 大标题 + 痛点钩子 + 代表画面)
     ↓ 输出
   60-90s 横屏 mp4 + 9:16 竖屏剪辑版 (备份, 用于视频号小红书)
     ↓
[Step 8] 推送 Joker 微信审稿 (~30 分钟超时默认通过)
     ↓
[Step 9] Playwright 自动上传 抖音 + 视频号 (待实现)
     或手动: Joker 收 mp4 + 上传
```

**总成本/条**: ~¥1
**总耗时**: ~5-10 分钟 (主要 Seedream 出图 70s/张 × 8 = ~10 分钟)
**¥200 余额够 200 条** (约 9 个月日更)

---

## 工具链状态

| 阶段 | 工具 | 状态 |
|---|---|---|
| 复盘原文 | KK schtasks JTC_DailyReview | ✅ 已跑 (5/22 测过 2951 字优质复盘) |
| LLM 抽脚本 | Doubao-pro / DeepSeek | ✅ key 已配 (火山方舟 + DeepSeek 双备份) |
| 静态图 | Seedream 4.5 (火山方舟) | ✅ 实测 ¥0.09/张 |
| 配音 (临) | edge-tts zh-CN-YunjianNeural | ✅ |
| **配音 (目标)** | fish-speech 本地 (KK) + Joker 声纹 | ⏳ **装中** (Joker 选 C 路径 5/25 02:30 启动) |
| 字体 | SourceHanSerifSC-Bold.otf | ✅ 已下载 4.2MB |
| 合成 | ffmpeg 7.1 + PIL | ✅ |
| 封面 | PIL + Seedream 单图 | ⏳ v5 实现 |
| 上传 | Playwright (抖音 / 视频号) | ⏳ 待 (短期 Joker 手动) |

---

## v4 配置 (当前测试中)

`scripts/generate_v4.py`:
- 横屏 1920×1080 (Seedream 出 2560×1440)
- edge-tts 云健 rate=0%
- 思源宋体粗体 64px 白字 + 5px 黑描边
- 字幕固定居中, 距底部 100px
- ken burns: zoom 1.0→1.1
- 8 段 × ~6s = 50s
- **乔克交易社文案方向**: "10 次只对 3 次的秘密" — Joker 灵魂金句

测试输出: `~/ai_video_workspace/output/demo_v4/v4_4-5_horizontal.mp4`

---

## v5 计划 (集成 Joker 声音)

替换 v4 的 edge-tts → fish-speech (KK 本地, ssh 调用):

```python
# v5 改 gen_tts 函数
def gen_tts_fish(text, out_path):
    # ssh kk + fish-speech inference + scp 回 mac
    text_file = "/tmp/tts_input.txt"
    open(text_file, "w").write(text)
    scp(text_file, "kk:C:/Tools/fish-speech/inputs/")
    ssh_kk(f"cd C:/Tools/fish-speech && python -m fish_speech.tools.inference"
           f" --text @inputs/{Path(text_file).name}"
           f" --reference_audio voice_clone/joker_voice.m4a"
           f" --output_dir outputs/")
    scp("kk:C:/Tools/fish-speech/outputs/output.wav", str(out_path))
```

预期效果: 视频里听到的就是 Joker 自己的声音 (而不是 edge-tts 默认 voice).

---

## Cron 自动化 (5/26 周一启动)

```
KK schtasks 每个交易日 16:35 (复盘出来后 5 分钟):
   1. ssh mac /Users/joker/ai_video_workspace/scripts/daily_video.sh
       └─ 跑 daily_video.py:
           a. 读 ~/Marketing/乔克交易社/每日复盘自动化/复盘_M_DD.md
           b. LLM 抽脚本 (8-10 段)
           c. Seedream 出 8-10 张图
           d. fish-speech 生成 8-10 段 Joker 声音
           e. ffmpeg 合成 mp4
           f. 推 Joker 微信审稿
   2. Joker 30 分钟内回 "OK"
   3. Joker 手动上传抖音/视频号 (或 Playwright 自动)
```

---

## Open Threads

**5/25 凌晨自主推进**:
- [ ] fish-speech 装好 (Monitor 中)
- [ ] v4 横屏 demo 跑出来 (Monitor 中)
- [ ] v5 集成 Joker 声音 (fish-speech 装好后)
- [ ] 写 daily_video.py 端到端

**等 Joker 起床 (5/25 早上)**:
- [ ] 看 v4 横屏 demo 效果, 反馈
- [ ] 听 v5 用 Joker 声音的 demo
- [ ] 决定 5/26 是否启动 (或先调 v6)

**5/26 周一**:
- [ ] 第一次实跑 (A 股复盘出来后)
- [ ] 上传抖音 + 视频号 (手动 or auto)
- [ ] 24 小时数据看流量

---

## 关键判断 / 决策记录

| 决策 | 依据 | 时间 |
|---|---|---|
| 用 fish-speech 不用云 TTS | 0 成本长期, KK 5070Ti 够跑, 中文质量 SOTA | 5/25 02:25 Joker 选 C |
| 配音用 Joker 自己声音 不用 AI | 真人 IP 戒备解药 (跟 [[01_乔克交易社/05_AI合伙人工作手册]] 同源) | 5/25 02:00 Joker 反馈 |
| 横屏 16:9 不用 9:16 | 浮光夜读真账号横屏, 内容多, 观众停留时间长 | 5/25 02:00 Joker 反馈 |
| 文案乔克方向 不用泛拆书 | 已建乔克交易社业务方向, 视频是其内容生产线 | 5/25 02:00 Joker 反馈 |
| 静态图为主 不用 Seedance 视频 | 浮光夜读真视频也全静态 + ¥1/条 vs ¥7/条 性价比 | 5/25 01:30 已决 |
