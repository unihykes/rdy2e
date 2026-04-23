# Cursor 3.0-multi-workspace-实践经验

官方文档：<https://cursor.com/cn/docs/agent/agents-window>

## 关键能力：Multi-workspace

在官方介绍里，有一句容易被忽略，但对我影响很大的描述：

> Features Available Only in the Agents Window  
> Multi-workspace: work with agents across all your projects from one place.

## 我的痛点（Cursor 2.0 阶段）

过去我通常把多个代码仓库都放进同一个工作区。这样做在日常开发中看起来方便，但在使用 Agent 时会出现明显问题：

- Agent 容易在多个仓库之间“串上下文”；
- 当仓库业务差异较大时，更容易出现回答偏题或引用错误代码的情况；
- 结果是 AI 幻觉概率变高，任务准确性下降。

## 迁移到 Agents Window 之后的变化

启用 Multi-workspace 后，我采用了「一个仓库一个工作区」的方式：

- 每个工作区只承载一个代码仓库；
- Agent 在当前工作区内工作，看不到其他仓库代码；
- 各工作区中的 Agent 只处理对应业务域。

实际体验是：上下文更干净、回答更聚焦、执行结果更稳定，整体准确性明显提升。

## 我的实践建议

- **按业务边界拆分工作区**：不要只按技术栈拆分，优先按业务域拆分；
- **避免把无关仓库混在同一工作区**：尤其是命名或结构相似的仓库；
- **任务开始前先确认当前工作区**：减少上下文误用；
- **长期任务固定在同一工作区完成**：提升连续性和一致性。
