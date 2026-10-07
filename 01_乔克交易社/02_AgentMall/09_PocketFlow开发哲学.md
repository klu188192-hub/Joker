# 09 · PocketFlow 开发哲学 (Joker Agent 开发的方法论圣经)

> **用户角色**: 提需求 + 拍板
> **CC 角色**: 按本哲学落地 (永不引入新框架 / 永不写继承 / 永不平级调用 LLM)
>
> 同步副本:
> - **我开发时直接调用**: `~/.claude/skills/joker-agent-dev/SKILL.md`
> - **我跨 session 自动遵循**: `~/.claude/projects/-Users-joker/memory/feedback_joker_pocketflow_philosophy.md`
> - **你查阅 (本文件)**: Obsidian `01_乔克交易社/02_AgentMall/09_PocketFlow开发哲学.md`

---

## 0. 我们如何走到这里 (5/31 的关键认知跃迁)

| 时刻 | 用户洞察 | CC 错误 | 修正方向 |
|---|---|---|---|
| 17:50 | "速度太慢" | 加 timeout / 加缓存 (单点优化) | 真正的并行 + 流式 SSE |
| 18:10 | "数据是历史快照吗" | LLM 在脑补 | 数据时间戳 + 强系统 prompt |
| 18:30 | "pocketflow 框架是不是用得不灵活" | 我承认 chat 是 RPC | 5 层 Runtime + Plan-Execute-Synth |
| 19:00 | "01决策模式 / 平级调用 / 视觉功能无 LLM 串联" | 我又陷入"单点优化忽略生态" | 推翻自己写的 7 个 Node class, 改成 1 个 Node + 函数注入 |
| 19:30 | "框架默认工具固定, 实际生产要动态" | 我加 `build_tools_schema` 又被指出"只解决单点" | 5 层架构里 L3 治理是体系 |
| 20:00 | "好框架的 3 个 0: LLM/依赖/原型生产鸿沟" | nodes.py 还 import httpx | 抽 `core/llm.py`, nodes 0 模型耦合 |
| 21:30 | "框架臃肿是把同一模式做了几十遍" (跟量化里给一个 alpha 做无数 regime 一样) | 我又写了 PlannerNode/ExecuteNode/SynthNode 3 个 class | 推翻, 改成 3 个 Node 实例 + 6 个函数 |
| 22:00 | "经典 RAG 链, 分块/向量化/存储/检索/生成, 都只不过是同一张图" | — | 内化: 所有 AI 产品 = Graph + Shared Store |

**这章 PocketFlow 第 2 章, 是上述系列对话的"原理书"**.

---

## 1. Node = 三步式 prep / exec / post

```
                ┌─────────────────────────────────────┐
shared store    │  prep    : 从台面拿食材 (只读)       │
   ⇅ read       │            返回 shared 需要的部分    │
                ├─────────────────────────────────────┤
                │  exec    : 锅里炒                   │
no shared       │            调 LLM / 调 API / 算数   │
                │            不动 shared, 可重试       │
                ├─────────────────────────────────────┤
shared store    │  post    : 把菜放回台面             │
   ⇅ write      │            返回动作字符串路由        │
                └─────────────────────────────────────┘
```

### 1.1 三步的可靠性 (本章核心论点)

| 步骤 | 副作用 | 可靠性 | 能否安全重试? |
|---|---|---|---|
| prep | 没有 (只读) | 通常可靠 | 不需要 |
| exec | 没有 (纯计算) | 经常不可靠 (LLM / 网络) | **可以** |
| post | 有 (只写 shared) | 通常可靠 | 不需要 |

**为什么 exec 安全可重试?**

因为它不碰 shared store. 三次模式不是花架子, 是隔离故障的设计:
- 重试一次, 数据库追加; 重试两次, 数据库再追加 → ❌ 数据重复 (没有三步式)
- 三步式重试: prep 还是读到原来的 5, exec 加 1 得 6, post 写回 6 (无副作用重试) → ✅

**Joker 已落地**: `api/core/flow.py::Node.run()` 把 `wait_for + max_retries + retry_delay` 全包了, 业务代码不写 try/except.

### 1.2 Node 实例化, **永不继承**

```python
# ✅ 对
plan_node = Node(name="plan", prep=p_fn, exec=e_fn, post=post_fn,
                 max_retries=3, retry_delay_sec=1, timeout_sec=20)

# ❌ 错 (我 5/31 晚上犯过)
class PlannerNode(Node):       # 这是把同一模式做了几十遍
    name = "plan"
    async def exec(self, prep): ...
```

---

## 2. Shared Store = 一个 dict, 一千条数据 / 一份共享记忆

- Node 之间不直接传参, 全靠 shared store 拼装
- 这就是 "一目了然", `print(shared)` 看到所有数据流转
- 不是数据库 / 不是消息队列 (单次执行的内存即可)
- 不需要 LangChain 的什么 12 种记忆类

**Joker**: `SharedStore` 就是 Python dict, ChatFlow 入口塞 `{db, user_id, handler, messages, sys_prompt}`, Node 之间通过 `store["tool_plan"]` / `store["tool_results"]` / `store["final_content"]` 传值.

---

## 3. Flow 四种组合 — 穷尽 AI 产品形态

### 3.1 链 (Chain)
最简单的连接模式: A 跑完跑 B, 看下一个该跑谁, 而连接节点的方式只有四种, 这就是整个 Flow 传应用都是这四种方式的排列组合.

```python
node_a >> node_b >> node_c
```

**应用**: LangChain Chain / RAG / 摘要 / 信息提取 / 多步骤数据加工.

### 3.2 分支 (Branch) — 一个动作字符串替代无数 if

```python
check >> "positive" >> double_it
check >> "negative" >> negate_it
```

分支让节点根据执行结果走不同的路. 它的机制很简单: `post` 返一个动作字符串, Flow 拿这个字符串去查下一个该跑哪个节点. 一个操作符创建条件转移.

**当 CheckSign 的 post 返 "positive" 时, 走 DoubleIt** (路径 → 6). "Agent 就是这么做决策的, 一个节点的结果, 字符串走不同的路."

### 3.3 循环 (Loop) — 节点指向自己

```python
chat_node >> "continue" >> chat_node    # 自循环
chat_node >> "exit"                     # exit 没 edge → flow 结束
```

框架里最强的模式是循环, 节点指向自己. Flow 按这个模式跑, 一个分支, 节点不读读取用户"exit"; **Agent 就是搭建这两个节点 AI 应用, 可以看到它们的代码不超过 30 行**.

### 3.4 嵌套 (Nest) — Multi-Agent 是嵌套四种方式

外部 Flow 把内部 Flow (`inner_flow`) 当成一个普通节点, 框架本身不会变复杂. 在平里里面还有一整张图. 用简单零件搭复杂系统, 框架本身是多 Agent 系统里的一个节点. 像支付下单是网购的一个步骤, 一个 Agent 可以是多 Agent 系统里的一个节点.

### 3.5 整个编排引擎就是一个 while 循环 (6 行代码)

```python
def _orch(self, copy, shared, params=None):
    curr = copy.copy(self.start_node)
    last_action = None
    while curr:
        last_action = curr._run(shared)
        curr = copy.copy(self.get_next_node(curr, last_action))
```

> "整个编排引擎就这点事: 跑一个节点, 拿下一个节点, 然后重复此过程. 没有调度器, 没有事件系统, 没有重定义任何类, Python 允许你重定义 \_\_sub\_\_ 和 \_rshift\_, 一操作符和 1; 每个 AI 应用都能映射到这 4 种方式."

| 应用 | 怎么映射 |
|---|---|
| 聊天机器人 | 一个节点循环指向自己 |
| RAG 管线 | 五个节点串成链 |
| Agent | 决策节点分支到任何工具, 再循环回来 |
| 审批流程 | 通过 → 处理, 拒绝 → 通知 |
| 多 Agent | 嵌套 Flow — 每个 Agent 是一个 Flow 当 Node 用 |

---

## 4. 调大模型: 框架的封装是个累赘 (反 LangChain)

PocketFlow 框架里零大模型代码, 没有 DeepSeek 的 import, 没有通义千问的 import, 没有模型配置, 翻遍 100 行你找不到任何供应商的影子. 大模型最重要的设计决策决定?

去翻 LangChain 的源码, 数数大模型封装类: `ChatOpenAI, ChatAnthropic, ChatGoogleGenerativeAI, ChatOllama, ChatCohere, ChatFireworks` 等几十个, 每个都有自己的参数, 自己的怪癖, 自己的 bug. LangChain 维护者就得手忙脚乱地更新每次供应商改 API (他们一直在改), LangChain 维护就只能跟着补. 你不光等着供应商, 用户提问题 (issue), 生产应用就跟着补 LangChain 对供应商 API 的解读, 一个故障点变成你自己写的一个 10 行函数.

### 4.1 替代方案: 简单到离谱

```python
# DeepSeek (兼容 OpenAI SDK, 改 base_url 即可)
from openai import OpenAI
client = OpenAI(
    api_key="your-deepseek-api-key",
    base_url="https://api.deepseek.com",  # 改这一行
)
def call_llm(prompt):
    r = client.chat.completions.create(
        model="deepseek-chat",
        messages=[{"role":"user","content":prompt}],
    )
    return r.choices[0].message.content
```

**全 4 个例子都从这里 import**, 本书 `call_llm.py`, `call_llm(prompt)` 一模一样, 签名一致, 4 个函数, 四个参数, 完全不用改.

从 DeepSeek 换到通义千问, 就是换一个 base_url 和模型名, 代码完全不用改, 不用改 Flow, 不用改节点, 不用改架构, 直接换就完了.

### 4.2 替供应商封装是"好框架"反方观念

PocketFlow 框架的好观念恰恰相反 — 你封装大模型, 不用等框架维护者. DeepSeek 从 V2 到 V3 改过接口, 阿里云百炼接口, 各家大模型的 API 都在快速迭代, 零大模型代码的框架在改进迭代而已. 是唯一一个不依赖供应商.

### 4.3 2026 年初供应商价格表 (用于成本决策)

| 模型 | 输入 ¥/百万 token | 输出 ¥/百万 token | 上下文窗口 |
|---|---|---|---|
| **DeepSeek-V3.2** | 2 | 3 | 128K |
| **Qwen3.5-Plus** | 0.8 | 2 | 128K |
| Kimi K2.5 | 3.2 | 15.5 | 256K |
| Qwen-Long | 0.5 | 2 | 1M |
| Ollama (本地) | 免费 | 免费 | 8-128K |

国产前沿模型已经非常便宜. 几个大模型按词元 (token) 计费, 不是按字数. 一个 token 大概对应 3/4 个英文单词或 1-2 个汉字, 中文比英文要塞 2~4 倍. 上下文窗口 (context window) 是单次请求能塞的最大 token 数 (输入+输出), 超出会直接报错.

### 4.4 Joker 落地

`api/core/llm.py`:
```python
default_llm = deepseek_chat
# 切 Gemini? → default_llm = gemini_chat
# 切通义? → default_llm = tongyi_chat (加 10 行 tongyi_chat 函数)
```
nodes.py 不动一行.

---

## 5. 30 行的聊天机器人 (合在一起)

第 1 章里 LangChain 那堆记忆类的坑, 干的都是同一件事: 在列表里追加内容. 你用过的每一个聊天机器人, DeepSeek, Kimi, 通义千问, 底层都是循环, 打印回复, 然后循环, 如图 2.6 所示.

```
┌──────────────┐
│ 聊天节点      │  ←──┐
└──────┬───────┘    │
       │            │
       ▼            │
   continue ────────┘
       │
       ▼
    (结束)  ←── exit
```

### 5.1 完整代码 (用户拍照原文)

```python
from pocketflow import Node, Flow
from call_llm import call_llm

class ChatNode(Node):
    def prep(self, shared):
        user_input = input("你: ")
        if user_input.lower() == "exit":
            return None
        shared.setdefault("messages", []).append(
            {"role":"user","content":user_input})
        return shared["messages"]

    def exec(self, messages):
        if messages is None:
            return None
        prompt = "\n".join(f"{m['role']}: {m['content']}" for m in messages)
        return call_llm(prompt)

    def post(self, shared, prep_res, exec_res):
        if prep_res is None:
            return "exit"
        print(f"机器人: {exec_res}")
        shared["messages"].append({"role":"assistant","content":exec_res})
        return "continue"

chat = ChatNode()
chat >> "continue" >> chat
Flow(start=chat).run({})
```

### 5.2 这里两件事值得注意

**第一**: prep 调了 `input()` — 严格来说 prep 应该保持纯净. 关键是使 exec 接受字符串, 因为前文的 `call_llm` 接受字符串. exec 把消息列表拼成 1 个字符串调 `call_llm` 并拼接成用户和助手的回复, 拼成字符串保留三个方法在阶段一个自循环.

**第二**: shared 只读 shared, 但用户输入也是一种数据来源.

(运行过程, 第 1 轮你输入"你好!", 第 2 轮"写首俳句", 第 3 轮"exit".)

### 5.3 没有记忆的智能体

如果你看过 50 First Dates (《初恋 50 次》) 的话, Drew Barrymore 演的角色有短期记忆障碍, 每天早上醒来都不记得发生的任何事. Adam Sandler 演的角色让 10 月 13 日, 完全不记得重新自我介绍, 重新解释两人的关系. 后来他开始每天早上回放一段录像带给她看; "嗨, 我是 Henry, 我们在一起了一年, 来她开始每天补上进度, 表现得好像她记得之前发生的所有事都在这, 全靠录像带在撑着."

```
┌──────────────────┐
│   每次醒来一片空白  │
│                  │
│   "我们昨天聊了什么?"│  ←── 让我从头读所有内容...
│                  │            ⇅
│                  │      重新读取所有消息
└──────────────────┘
```

你的大模型就是 Drew Barrymore, 消息列表就是录像带. 我们说你是谁, 调用模型都把整段对话历史塞进 prompt, 但翻翻 API 日志就知道真相干, 每次 API 调用模型都把整段对话历史塞进 prompt, 但翻翻你的 API 日志就知道真相: DeepSeek 这样干, Kimi 这样干, 用过的每个机器人都这样干.

### 5.4 token 累积 (重点)

消息 (messages) 有三种角色: `system` (设定行为), `user` (你的输入), `assistant` (模型的回复). 单轮请求只需一条 user 消息; 多轮对话只需在列表里追加内容.

温度 (temperature) 控制随机性: 0 用于确定性提取, 0.7~1 用于创意任务. 拿不准就用默认值.

| 轮次 | 发送给大模型的消息 | token 消耗 |
|---|---|---|
| 1 | [user: "你好!"] | ~5 token |
| 10 | [user: "你好!", assistant: "你好!", ..., user: "..."] (全部 20 条) | ~30 token |
| 100 | (全部 200 条前面被"忘"的消息被截掉了) | ~60 token |

可以发现列表越来越长, 第 10 轮发全部 20 条消息, 也是模型聊到后面会"忘"前面内容的原因. 这就是上下文窗口超出了 / 而是对话超出了上下文窗口, 最早的消息被截掉了.

现在回头看那十二个 LangChain 记忆类 (`ConversationBufferMemory`, `ConversationTokenBufferMemory`, `ConversationBufferWindowMemory` 等), 一行代码能干的事被埋进六层抽象, 不是按 token 计数 (`list[-k:]`), 每次你要调试聊天机器人就一个 — 但原因从来跑哪, 检索压缩, 摘要, 都是哪个 — 谁就是卖你一个记忆类, 谁就是高级记忆策略, 在卖你一个套.

记忆就是 `messages.append()`, 谁是看你一个独立的关注点, 重试逻辑不跟干活的对象放在一起.

→ **结论**: 不用 LangChain, 用 PocketFlow 是 100 行 Node 类的代码 (不是 BaseNode, 这才是你实际用的版本)

---

## 6. 重试和兜底: 别自己写 try/except

你的第一个大模型应用一定会在深夜两点被限流拖跨, 不是可能, 不是一定. 大模型 API 返回 500 错误 (内部服务器错误), 限流飙升, 网络连接在响应中途断开. 如果你的应用就一失败就崩开. 那么的应用就是个玩具.

每本 Python 教程都教你用 try/except 处理这种问题:
```python
try:
    result = call_llm(prompt)
except Exception as e:
    result = fallback_value
```

对大模型应用来说, 这么写恰恰是错的. 你的 try/except 第一次失败就吞掉错误, 这写, 没有重试, 没有恢复机会, 也没有第二次机会, 只能直接走兜底.

### 6.1 正确版本: 用 Node 自带的重试 + 兜底

```python
class Node(BaseNode):
    def __init__(self, max_retries=1, wait=0):
        super().__init__()
        self.max_retries = max_retries
        self.wait = wait

    def exec_fallback(self, prep_res, exc):
        raise exc

    def _exec(self, prep_res):
        for self.cur_retry in range(self.max_retries):
            try:
                return self.exec(prep_res)
            except Exception as e:
                if self.cur_retry == self.max_retries - 1:
                    return self.exec_fallback(prep_res, e)
                if self.wait > 0:
                    time.sleep(self.wait)
```

接口就是两个参数加一个重写: `max_retries` 控制 exec 重试几次, `wait` 控制两次之间等多少秒, `exec_fallback` 是兜底逻辑 — 如果所有重试都失败, 网络等都失败 — 重试循环帮你捕获异常, 但不像你写的 try/except, 第一次失败就只能直接走兜底.

### 6.2 实例

```python
from pocketflow import Node
import random

class UnreliableAddOne(Node):
    def prep(self, shared):
        return shared["number"]

    def exec(self, prep_res):
        if random.random() < 0.5:
            print(" 失败了! 重试中...")
            raise Exception("瞎机失败!")
        print(" 成功!")
        return prep_res + 1

    def exec_fallback(self, prep_res, exc):
        print(" 所有重试都失败了, 使用兜底方案")
        return prep_res  # 返回原始数字而不是崩溃

    def post(self, shared, prep_res, exec_res):
        shared["number"] = exec_res

node = UnreliableAddOne(max_retries=3, wait=1)
shared = {"number": 5}
node.run(shared)
print(f"结果: {shared['number']}")
```

### 6.3 典型的执行结果 (表 2.14)

| 尝试 | 发生了什么 | 等待 |
|---|---|---|
| 1 | exec 抛异常 | 1 秒 |
| 2 | exec 抛异常 | 1 秒 |
| 3 | exec 成功, 返回 6 | — |

由表 2.14 可知, `shared["number"]` 是 6, 如果三次都失败了, `exec_fallback` 会返回原始的 5, 而不是让整个应用崩掉.

### 6.4 想一想, 为什么它能干干净净地运行

前文把节点拆成 prep/exec/post, exec 不破 shared, 重试三次零副作用. 三步模式不是花架子, 没有重复数据, 没有污染. 三步就是为了能安全地重试不可靠的那部分, 而不用重跑读写 shared store 的部分, 如表 2.4 所示.

大模型 API 的不稳定定是常态: DeepSeek 高峰期限流频发, 阿里云百炼的时候响应变慢甚至超时, Kimi 在 API 负载 API 重试装饰器, 大多数因队后才补错容错机制 — 这里加个重试装饰器, 那里加个中间件, 再来个熔断器, 一年后才补容错全搞了 — 生产级容错不是一个独立的关注点, 它是每个节点上的关键参数: `max_retries, wait, exec_fallback`. 重试逻辑不跟干活的对象放在一起, 那就是放错地方了.

---

## 7. 结构化输出: 让大模型乖乖听话

大模型生成文本当聊天机器人用挺好, 但你需要数据时就不好用了. 你让大模型从简历里提取信息, 比如姓名, 邮箱, 技能列表, 它会给你一段写得很漂亮但叙叙的话, 你没法直接把这段话直接用作邮箱数据. 解决办法是让大模型按结构化格式回复, 而格式的选择比你想想的重要得多, 如图 2.8 所示.

### 7.1 为什么用 YAML 而不是 JSON

你的第一反应肯定是用 JSON, 但 JSON 有个让大模型头疼的毛病: 需要转义. 字符串里的引号要用 `\"`, 换行要用 `\n`, 反斜杠要用 `\\`. 简单的问题用 JSON 处理 (`json.loads()`), 但内容里一旦出现引号或特殊字符, 大模型就忘了. 一份完整的简历数据在两种格式下的样子:

```json
{
  "name": "张三",
  "summary": "搭建了一个\"颠覆性\"的\n数据管线系统",
  "skills": ["Python", "FastAPI", "PostgreSQL"]
}
```

```yaml
name: 张三
summary: 搭建了一个"颠覆性"的
数据管线系统
skills:
  - Python
  - FastAPI
  - PostgreSQL
```

YAML 不需要转义, 引号就是引号, 换行就是换行, 大模型写起来自然.

`yaml.safe_load()` 解析也干干净落, YAML 就是更容易写对的格式. (但 yaml.safe_load() 解析也千净利落, 写之相对于大类的缩进数据无声息地没列表.)

但这里也有个坑: YAML 的 | 块数据根据第一行去掉缩进对相比类的空白外内容用 JSON 编码, 虽然格式比如你让大模型输出一段代码, 代码因为类里在面所以本身有缩进:

```yaml
code: |
    def hello():
        print("hello world")
```

YAML 的 | 块会根据第一行去掉前导缩进, `yaml.safe_load()` 返回 def 前面的六个空格完整保留, 相对于类的缩进缩进悄无声息地没了. YAML 合法, 但 Python 报错了.

这种情况下, 每个空格都显式, def 前面的六个空格代码补丁将致 17 次 IndentationError 错误, 换成 JSON 编码字符串. JSON 编码代码, 内容用 YAML, 提取数据用 YAML 内容包括代码用 JSON, 结论很简单: YAML 合法, 但 Python 报错了.

Agent 的时候 (第 10 章), 内容用 YAML, 代码用 JSON.

### 7.2 验证 + 重试 = 可靠性

让大模型输出 YAML 能解决大部分问题, 但这"大部分"还达不到生产级别. 有时候大模型缩掉一个字段, 有时候它把 skills 输出成字符串而不是列表. 第一种解决办法是验证加重试, 这时 2.5 节就派上用场.

下面通过一个简历解析器演示 YAML 提取, 验证和重试的配合:

```python
from pocketflow import Node
from call_llm import call_llm
import yaml

class ParseResume(Node):
    def prep(self, shared):
        return shared["resume_text"]

    def exec(self, resume_text):
        prompt = f"""从这份简历中提取信息, 以 YAML 格式输出:

{resume_text}

```yaml
name: 全名
email: 邮箱地址
skills:
  - 技能 1
  - 技能 2
```"""

        response = call_llm(prompt)
        yaml_str = response.split("```yaml")[1].split("```")[0].strip()
        result = yaml.safe_load(yaml_str)
        assert "name" in result
        assert "email" in result
        assert isinstance(result["skills"], list)
        return result

    def post(self, shared, prep_res, exec_res):
        shared["parsed"] = exec_res

resume = """张三, zhangsan@example.com
资深 Python 开发者, 5 年经验.
技能: Python, FastAPI, PostgreSQL, Docker, AWS"""

shared = {"resume_text": resume}
ParseResume(max_retries=3).run(shared)
print(shared["parsed"])
```

看看验证失败时会怎么样: 假设大模型返回 YAML 里 `skills: "Python, FastAPI"` 是字符串而不是列表, `assert isinstance(result["skills"], list)` 触发 `AssertionError`. 因为 exec 是纯函数调用, 上次的大模型半成品不会残留, 上次的大模型单次调用有 80% 的概率输出正确格式, 三次重试就意味着三次都失败才算失败 — 0.2 × 0.2 × 0.2 = 0.8% 失败率, 把一个 80% 可靠的模型变成 99.2% 可靠的系统, 足以达到生产级别, 如表 2.15 所示.

| 尝试 | 单次成功率 | 累计失败率 |
|---|---|---|
| 1 | 80% | 20% |
| 2 | 剩下 20% 中的 80% | 4% |
| 3 | 剩下 4% 中的 80% | 0.8% |

### 7.3 供应商结构化输出: 连解析都不用了

第二种解决办法: 让供应商强制制数据结构 (schema), 直接跳过解析. DeepSeek 的结构化输出, 会让你传一个 JSON schema, API 保证回复匹配 schema, 不需要 YAML, 不需要解析, 不需要断言 (assert).

解决方法是在你的 `call_llm` 函数上加一个可选的 `output_model` 参数:

```python
from openai import OpenAI
from pydantic import BaseModel

client = OpenAI(
    api_key="your-deepseek-api-key",
    base_url="https://api.deepseek.com",
)

def call_llm(prompt, output_model=None):
    if output_model:
        r = client.chat.completions.parse(
            model="deepseek-chat",
            messages=[{"role":"user","content":prompt}],
            response_format=output_model,
        )
        return r.choices[0].message.parsed
    r = client.chat.completions.create(
        model="deepseek-chat",
        messages=[{"role":"user","content":prompt}],
    )
    return r.choices[0].message.content


class ResumeData(BaseModel):
    name: str
    email: str
    skills: list[str]
```

现在简历的解析器变得极其简单:

```python
class ParseResume(Node):
    def prep(self, shared):
        return shared["resume_text"]

    def exec(self, resume_text):
        return call_llm(f"提取信息: \n{resume_text}", output_model=ResumeData)

    def post(self, shared, prep_res, exec_res):
        shared["parsed"] = exec_res
```

没有 YAML 模板, 没有字符串切割, 没有 assert — schema 就是 Pydantic 类, `.name`, `.email`, `.skills` 都有类型. `exec_res` 直接是一个 ResumeData 对象. 同一个 `call_llm` 兼容所有模型. YAML 模板和多供应商场景用 YAML, 单供应商的生产系统用供应商结构化输出, 后文我们会讲到. 复杂的嵌套 schema 就拆成多个简单的大模型调用, 这叫任务拆解.

---

## 8. 批处理: 同一个节点, 1000 条输入

你刚搭了一个处理单份简历的解析器, 但客户发来了一千份简历, 你的第一反应肯定是写个 for 循环:

```python
for resume in resumes:
    result = parse_one(resume)
    results.append(result)
```

要是第 47 份简历抛出异常, 那么整个批次全崩, 问题喷涌而来. 你将开始写记账代码, 断点续传; 从头重来; 跳过第 47 份继续执行? 如何记录哪些成功了? 整个批次重新尝试.

进度条, 最重要的业务逻辑反而没有顾及. 每个开发者都过这个循环, 每个开发者都写过这个问题, 整个类就三行:

```python
class BatchNode(Node):
    def _exec(self, items):
        return [super(BatchNode, self)._exec(i) for i in (items or [])]
```

仔细看, 它对每一份简历单独调用 exec, 也就是说, 它自己重试三次. 它对每一份历都处理失败了? 它自己 47 份历处理失败了 — 不需要进度条, 不需要断点, 不需要重试. 影响, 不需要记账, 不需要进度条. 通过表 2.17 可以看出, BatchNode 与普通 Node 的区别小. 通过表 2.17 可以看出, BatchNode 与普通 Node 的区别小.

| 方法 | 普通 Node | BatchNode |
|---|---|---|
| prep 返回 | 一条数据 | 一个列表 |
| exec 收到 | 那一条数据 | 还是一条 (BatchNode 逐条调用) |
| post 收到的 exec_res | 一个结果 | 一个结果列表 |

关键是 exec 不用改 — 你写单条逻辑, BatchNode 负责一个批量评论摘要器. 让我们来搭建一个批量评论摘要器:

```python
from pocketflow import BatchNode
from call_llm import call_llm

class SummarizeReviews(BatchNode):
    def prep(self, shared):
        return shared["reviews"]                          # 返回一个列表

    def exec(self, review):                               # 收到一条评论
        return call_llm(f"用一句话总结这条评论: {review}")  # 收到一条评论

    def post(self, shared, prep_res, exec_res):
        shared["summaries"] = exec_res                    # 收到一个摘要列表

reviews = [
    "来很好吃但服务太慢了, 我们等了 30 分钟. ",
    "全城最好吃的比萨! 酥脆的饼底, 新鲜的食材. 还会再来. ",
    "性价比太低了. 意面没味道, 分量还小. ",
]
shared = {"reviews": reviews}
SummarizeReviews(max_retries=3).run(shared)
for i, s in enumerate(shared["summaries"]):
    print(f"评论 {i+1}: {s}")
```

再看 exec, 它压根不知道自己是批处理的一部分, 只是看到一条评论, 就返回一条评论, 同样的 prep/exec/post 模式, 同样的思路, 同样的大便宜.

BatchNode 适合条目之间独立的场景: 摘取 1000 份简历, 翻译 1000 句话, 解析 1000 条评论, 换了个类名就行.

但如果条目之间有依赖呢? 比如写一章一节小说, 第 3 章得知道第 2 章学过案了什么, 不需要新的框架功能, 不需要独立处理. 不需要新的框架功能, 不需要其他条目的节点加一个 shared store 里的索引:

```python
class WriteChapter(Node):
    def prep(self, shared):
        i = shared.get("chapter_index", 0)
        return {
            "index": i, "outline": shared["outlines"][i],
            "previous": shared.get("chapters", []),
        }

    def exec(self, prep_res):
        context = "\n".join(prep_res["previous"])
        return call_llm(f"前面的章节: \n{context}\n\n写这一章: {prep_res['outline']}")

    def post(self, shared, prep_res, exec_res):
        shared.setdefault("chapters", []).append(exec_res)
        shared["chapter_index"] = prep_res["index"] + 1
        if shared["chapter_index"] < len(shared["outlines"]):
            return "continue"

writer = WriteChapter(max_retries=3)
writer - "continue" >> writer
```

与 2.2 节一模一样的循环模式, 都由 PocketFlow 100 行里同一段 6 行的不需要新 API, 不需要什么 SequentialProcessor 或 StatefulIterator. 框架没变复杂, 不需要新 API, 不需要什么 SequentialProcessor 或 StatefulIterator. 框架没变复杂, 变的是图的形状, 如表 2.18 所示.

---

## 9. 异步和并行: 10 秒变 1 秒

BatchNode 的逻辑是一条一条处理: 调大模型处理第 1 条评论, 等回复; 调大模型处理第 2 条评论 (假如有 10 条评论). 假如调第 1 条不超过 1 秒, 第 3 条评论不需要调用模型, 第 1 秒的真实时间花了 10 秒, 等网络. 那么你这个用 10 秒等模型回复, 结果你在花着天花板 — 等网络, 因为换个类名就可以可以提速 10 倍. 并行调用大模型唯一是, 见图 2.9.

### 9.1 异步不是什么并发黑魔法, 只是把空闲时间捡回来

异步 (async) 发起一个任务, 不等它完成就发下一个, 等待返回才能发下一个的, 普通 Python 每次 API 调用都要等返回才能发下一个, 而 async def 声明一个可以暂停的函数, await 表示 "发起这个调用, 等的时候去跑别的". 就这点事, 代码一看就懂.

```python
import asyncio, time

async def fake_api_call(item):
    await asyncio.sleep(1)       # 模拟 1 秒的 API 调用
    return f"已处理 {item}"

async def main():
    # 单行: 一条一条来
    start = time.time()
    results = []
    for item in ["a", "b", "c"]:
        results.append(await fake_api_call(item))
    print(f"串行: {(time.time() - start):.1f}s")   # ~3.0s

    # 并行: 全部一起
    start = time.time()
    results = await asyncio.gather(
        fake_api_call("a"),
        fake_api_call("b"),
        fake_api_call("c"),
    )
    print(f"并行: {(time.time() - start):.1f}s")   # ~1.0s

asyncio.run(main())
```

`asyncio.gather()` 接收多个异步调用, 并发执行, 并等待全部完成. 总耗时取决于最慢的那条, 不是加起来的那条. `asyncio.gather` 代替了 for 循环, 同样的单条逻辑, 同时发起了全部调用.

### 9.2 AsyncParallelBatchNode 把列表推导变成 asyncio.gather

AsyncParallelBatchNode (异步并行批处理节点) 干的就是把列表推导变成 `asyncio.gather`. 它在 PocketFlow 100 行里表现为下述的完整类:

```python
class AsyncParallelBatchNode(AsyncNode, BatchNode):
    async def _exec(self, items):
        return await asyncio.gather(*(super()._exec(i) for i in items))
```

对比 BatchNode 的 _exec:
```python
class BatchNode(Node):
    def _exec(self, items):
        return [super(BatchNode, self)._exec(i) for i in (items or [])]
```

列表推导这么多, 同一个 asyncio.gather, 一条一条处理和全部同时处理之间的区别就这么多. 框架改了, 但你的代码不动. 2.7 节评论摘要器的并行版本如下所示, 让我们看看改了多少:

```python
from pocketflow import AsyncParallelBatchNode, AsyncFlow
import asyncio

class ParallelSummarize(AsyncParallelBatchNode):
    async def prep_async(self, shared):
        return shared["reviews"]

    async def exec_async(self, review):
        return await call_llm_async(f"用一句话总结: {review}")

    async def post_async(self, shared, prep_res, exec_res):
        shared["summaries"] = exec_res

shared = {"reviews": reviews}
asyncio.run(AsyncFlow(start=ParallelSummarize(max_retries=3)).run_async(shared))
```

#### 一共改了三处:
1. `BatchNode 变成 AsyncParallelBatchNode`
2. `方法变成 async def 加 _async 后缀`
3. `Flow 变成 AsyncFlow (异步流程) 加 run_async`

节点逻辑 — prompt, 输入, 输出 — 完全没动, 10 条评论从 10 秒变成 1~2 秒, 如表 2.19 所示.

| 处理方式 | BatchNode | AsyncParallelBatchNode |
|---|---|---|
| 10 条 × 每条 1 秒 | 10 秒 | 1~2 秒 |
| 加重试 | 有 | 有 |
| 方法名 | prep, exec, post | prep_async, exec_async, post_async |

### 9.3 并发不总是更快 (反过拟合)

并行有时候反而会变慢 — 超出 API 限流的话尤其如此. 比如一次性发 100 个请求, 但 API 每秒只允 10 个, 90 个会被限流, 这 90 个被限流, 最后你花在处理 429 错误 (服务器限流保护), 还挤占下下一个时间窗口的配额. 上的时间比串行省下的还多. 串行加重试有时候反而比并行跑得下的还多. 串行加重试是简单, 因为串行根本不会触发限流.

而快的确认正确, 并行确实快, 但加你不会触发限流, 因为串行根本不会触发. 串行加并行加限流, 因为串行根本不会触发限流.

结论很简单: 先用串行跑跑看是不是真的不行, 再换成 AsyncParallelBatchNode, 看看是不是真的快了, 并行是你搞精精确 API 限制之后的奖励, 不是默认选项.

---

## 10. 本章要点表 (用户口述的)

> 上一章你看到了 100 行代码, 说它什么都能搭, 你八成还不信. 说它做不到三步循环这些, 你还是不信. 你还做不到看不到三步行, 也不知道那是因为没有点这些代码. 你一眼根据盘想想就知道怎么连节点, 你会搭一个聊天节点, 你需要转折一个节点, 本章是转折点. 你需要折点, 那么是转一千条数据, 批量处理结构化数据, 像专业棋手一样, 扫一眼简历就能解析, 把简历转成 100 行上. 读完这章, 没人教过你的东西也能理解这框架, 你不只能理解这个框架, 还会理解它为什么要这么设计.
>
> 整个框架就两个原语: 一个对象, 负责执行; 一个字典, 负责记忆. 一千活的 Node, 一个存数据的共享存储 (shared store), 其他所有的东西, 像 Flow, 重试, 批处理, 异步, 都是这两个的组合. 表 2.1 是你要搭的东西, 以及每块能解锁什么.

| 要点 | 解锁什么 |
|---|---|
| Node (prep/exec/post) | 全书每个节点都遵循三步模式, 拆开是为了让重试安全 |
| Flow (链/分支/循环/嵌套) | 四种组合, 无穷组合, 每个 AI 应用都是它们的排列 |
| 调大模型 | 是你自己的 10 行工具函数, 改一个函数, 换供应商 |
| 聊天机器人 | "记忆" 就是 `messages.append()`, 模型每次调用都是失忆的 |
| 重试 | 生产级容错就三个参数: max_retries, wait, exec_fallback |
| 结构化输出 | 让大模型返回数据用 YAML, 数据用 JSON |
| 批处理 | 同一个节点, 1000 条输入, 每条自动隔离故障 |
| 异步 | 10 秒变 1 秒, 换个类名就行 |

现在, 让我们从两个原语开始.

---

## 11. Joker 项目专用映射 (CC 开发时按表落地)

| 用户提的需求 | 对应 PocketFlow 原语 | Joker 具体落地点 |
|---|---|---|
| "加个炒股助手新功能" | 新 Node 实例 + 加 edge | `api/agents/stock_assistant/nodes.py` 加函数 + 改 `build_chat_flow()` |
| "改 chat 流程" | 改 Flow 拓扑 | `nodes.py::build_chat_flow` 的 `.connect()` |
| "做 RAG" (W14-15) | 链: chunk → embed → store → retrieve → generate | 在 `api/core/flow.py` 上加 RAG nodes |
| "F4 警报扫 1000 股" | BatchNode | 改 `api/agents/stock_assistant/F4_scanner.py` |
| "全市场 200 股并行画像" | AsyncParallelBatchNode | `data/manager.py` 多源拉数据时 |
| "切换 LLM 供应商" | 改 1 行 `default_llm` | `api/core/llm.py` |
| "速度太慢" | 检查是不是串行了 LLM/IO | 多 tool 用 `asyncio.gather` (已做) |
| "输出格式不稳定" | YAML + assert 重试 / DeepSeek `parse` | 新 Node 加 `max_retries=3` |
| "做新 Agent #N" | 嵌套 Flow / 加 chat_router 路由 | `api/agents/<new_agent>/nodes.py` |
| "多模态 (W5 截图理解)" | 链: vision_call → text_call | `api/core/llm.py` 加 `gemini_vision_call` |
| "Token 成本控制" | 滑动窗口 + 模型分层 | router 用 DeepSeek-chat / synth 用更便宜模型 |

---

## 12. CC 自我约束 (反模式, 永远不做)

- ❌ 引入新框架 (LangChain / CrewAI / LangGraph) — Joker 永远只用 `api/core/flow.py` 100 行
- ❌ 把 LLM 调用耦合到 Node 类里 — 用 `core.llm` 函数
- ❌ 为单点性能优化牺牲生态完整 — 跟量化 alpha 痛史一样, 不重蹈覆辙
- ❌ 给同一个模式做几十遍变体 — 用 1 个 Node 类参数化 (PlannerNode/ExecuteNode/SynthNode → 3 个 Node 实例)
- ❌ 自己写 try/except 吞错 — 用 Node 自带 `max_retries / wait / exec_fallback`
- ❌ 让 LLM 直接吐 JSON 不验证 — YAML / schema / max_retries=3
- ❌ 串行循环调 LLM — asyncio.gather + AsyncParallelBatchNode
- ❌ 把整页 markdown 当 tool 终点 — tool 返 structured data, 给后续 Synthesize 综合

---

## 13. CC 执行 SOP (每次接到需求按这个走)

```
Step 1: 映射     — 用户需求 → 表 (11) 的哪一行
Step 2: 检查     — 现有 nodes.py 是否已有类似 Node, 复用而不是新增 class
Step 3: 写代码   — Node() 实例化 + 函数注入, 0 新 class
Step 4: 链路     — 改 build_chat_flow() 加 connect, 不改 chat_v2_router 主框架
Step 5: 验证     — print(shared) 看每步状态, 不靠 LLM 调试
Step 6: 重试     — 新 Node 默认 max_retries=2~3
Step 7: 异步     — 多 IO 默认 asyncio.gather
Step 8: 结构化   — 关键 Node 用 YAML + assert
Step 9: 落定     — commit 时说明对应 PocketFlow 哪一节原语
```

---

## 14. 文档源头 (用户提供的实体书)

- **PocketFlow** 100 行 LLM 框架 · `The-Pocket/PocketFlow` (GitHub, Apache 2.0)
- **第 2 章** "每个 AI 框架底层都是同一个东西——图" (用户 5/31 拍照逐页, 第 16-42 页)
- 综合用户 5/31 系列追问 (01 决策 / 平级调用 / 框架臃肿 / 量化痛史) 的批评意见

更新时点: **2026-05-31**. 后续 Joker 任何 agent / chat / skill 工作, CC 先读本文.
