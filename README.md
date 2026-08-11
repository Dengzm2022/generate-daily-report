# generate-daily-report：基于 Git 证据的中文日报 Skill

这是一份面向 Codex 的工作日报 Skill。它从当前项目的 Git 记录和工作区差异中整理当天工作，再通过一轮有针对性的 grilling，让使用者确认哪些内容应写进日报。

执行规则以 SKILL.md 为准；本文件用于说明 Skill 的用途、证据边界、输出格式和包内资源。

---

## 使用方式

### 人类

```cmd
npx skills add https://github.com/Dengzm2022/generate-daily-report --skill generate-daily-report
```

### 智能体

```txt
Run `npx skills add https://github.com/Dengzm2022/generate-daily-report --skill "generate-daily-report"` and follow the generated skill instructions now. Read its complete output, redirecting it to a temporary file first if necessary. Resolve relative paths from the supporting-files directory it provides.
```



## 项目简介

generate-daily-report 用来生成当天的中文工作日报，固定输出四个部分：

1. 今日完成工作
2. 今日未完成工作
3. 今日遇到的障碍、风险、痛点、堵点
4. 今日沉淀内容

日报保存到当前项目根目录的 docs/daily-report 文件夹，文件名为：

~~~text
yyyy-MM-dd 日报.md
~~~

它不把提交标题直接当成工作结论，而是查看实际 diff，判断功能是否形成闭环，并把无法从代码确认的部分交给使用者确认。

## 适用场景

适合以下请求：

- “生成今天的日报”
- “根据当前项目的 Git 记录写日报”
- “整理今天完成和未完成的开发工作”
- “从代码差异里找出今天的风险、堵点和沉淀”

如果当前目录不是 Git 项目，Skill 会说明缺少代码证据，并询问是否改为只根据用户口述整理。

## 工作流程

### 1. 同步并确定报告范围

Skill 首先：

1. 找到当前项目根目录。
2. 使用本地日期作为报告日期；用户指定日期时以用户指定日期为准。
3. 运行 git fetch --all --prune，先同步所有远程分支。
4. 读取当前仓库配置中的 git user.name 和 git user.email。
5. 在所有本地分支和远程跟踪分支中搜索当天时间窗口内的记录。
6. 精确匹配当前 Git 用户的 author name、author email、committer name 或 committer email。

fetch 失败不会伪造成功状态。Skill 会继续使用已有记录，但会在报告中说明证据范围可能不完整。

### 2. 读取 Git 证据

对匹配到的记录，Skill 会保留：

- 短哈希、主题、作者和提交者
- 提交时间
- 所在分支或远程跟踪引用
- 涉及文件和实际 diff
- 上游是否能看到该记录的来源状态

同一个提交只处理一次。其他 Git 用户的记录不能直接写入当前用户的完成工作。

同时检查当前工作区的未暂存、已暂存和未跟踪差异。工作区 diff 默认先作为工作候选；如果不能确认归属于当前用户，会在 grilling 中询问。日报目录本身会从工作区候选中排除，避免把刚生成的日报重复统计。

### 3. 判断功能完整性

只要当前用户相关的记录或确认归属的工作区存在 Git diff，就先列入完成候选。随后检查：

- 入口、调用方或注册处是否已经接通
- 主流程是否可以走通
- 成功、失败和边界分支是否有处理
- 配置、依赖、迁移和文档是否齐全
- 测试、构建或静态检查是否提供相反证据
- 是否仍有 TODO、占位实现或用户确认的缺口

功能闭环且没有相反证据，才归入“今日完成工作”。功能不完整时归入“今日未完成工作”。未提交或尚未在上游可见，只标为来源状态，不会单独把一个完整功能降为未完成。

无法判断时保留“待确认”，不替用户猜测。

### 4. 从 diff 生成第三、第四项候选

Skill 会先从实际 diff 中提取候选，再让用户决定是否保留：

- 障碍：失败测试、缺失依赖、未接通路径、冲突或明确卡住的代码
- 风险：权限、认证、迁移、兼容性、硬编码、缺少失败处理或缺少测试
- 痛点：重复逻辑、临时绕过、脆弱分支、复杂调用链或明显的手工步骤
- 堵点：外部服务、环境、账号、依赖、接口、评审或决策等未满足的前置条件
- 沉淀：测试、工具函数、排查路径、根因判断、技术取舍、配置规则、命令、文档或可复用决策

候选会带上 diff 证据和置信度。没有代码迹象的内容只标成“待用户确认”，不会伪装成事实。

### 5. 通过 grilling 确认取舍

Skill 会向用户提出两类问题：

1. 当前记录和工作区候选是否属于本人，以及对应功能是完成、未完成还是待确认。
2. 障碍、风险、痛点、堵点和沉淀候选分别保留、删除还是修改。

用户可以改写候选的内容、归类和影响。用户选择删除的内容不会进入日报；用户说“跳过”时会保留“用户未补充”，不会把推荐答案当成确认事实。

### 6. 去模板化并写入日报

定稿前读取 references/humanizer-zh.md，保留事实、数字、文件名、命令、作者、分支和状态判断，只调整表达：

- 少用空泛的意义判断和宣传式结论
- 删除不必要的填充连接词、模糊归因和虚假范围
- 避免三段式堆砌、过度破折号和机械的总结语气
- 使用具体动词、名词和自然的长短句
- 不为了“像人”凭空添加感受、用户反馈或业务价值

最终文档只保留四个固定一级标题，不增加“总结”或其他第五项。

## 使用方式

安装并启用 Skill 后，可以直接提出：

~~~text
生成今天的日报
~~~

也可以明确指定：

~~~text
使用 generate-daily-report，根据当前项目 Git 记录生成今天日报。
~~~

如果需要更准确地判断某个功能是否完成，应在 grilling 阶段说明目标、当前状态、剩余缺口和希望保留的表述。

## 输出示例

~~~markdown
# yyyy-MM-dd 日报

## 一、今日完成工作

- <基于实际 diff 且功能闭环的工作点>

## 二、今日未完成工作

- <功能不完整的工作点和停留位置>

## 三、今日遇到的障碍、风险、痛点、堵点

- <用户确认保留的候选>

## 四、今日沉淀内容

- <用户确认保留的可复用经验或决策>
~~~

示例中的尖括号只是占位说明，实际日报不会保留未确认的占位内容。

## 包内文件

~~~text
generate-daily-report/
├── SKILL.md
├── README.md
├── LICENSE
├── agents/openai.yaml
├── references/humanizer-zh.md
└── scripts/collect_git_evidence.sh
~~~

- SKILL.md：给 Codex 执行的完整流程和判断规则
- README.md：本文件，介绍用途、证据边界和使用方式
- LICENSE：本 Skill 包的许可条款
- references/humanizer-zh.md：日报定稿时使用的去模板化检查规则
- scripts/collect_git_evidence.sh：采集日期、Git 身份、分支、记录和工作区差异的辅助脚本

## 边界与隐私

- Git 记录只能证明代码在什么时间、以什么身份出现在可见引用中，不能单独证明真实业务结果。
- Skill 不读取或输出 .env、密钥、证书、凭据等敏感内容，只记录必要的文件类型和风险。
- fetch、采集和生成日报不会自动执行 commit、push，也不会修改日报目录之外的项目文件。
- 没有匹配记录、fetch 失败或功能完整性证据不足时，报告会如实写明，而不是补齐一个看起来完整的故事。
- 日报中的第三、第四项以用户最终确认的候选为准。

## 参考来源

本 Skill 的文档结构和定稿检查思路参考了 [Humanizer-zh](https://github.com/op7418/Humanizer-zh) 的 README.md、LICENSE 以及其去模板化理念；grilling 流程参考 [mattpocock/skills](https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md)。

本 Skill 的 README.md 和 LICENSE 是针对日报 Skill 重新撰写的文件，不是 Humanizer-zh 文件的原文副本。版权与许可范围以包内 LICENSE 为准。
