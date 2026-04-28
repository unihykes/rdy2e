---
name: r2e-code-optimize
description: C++ 代码优化编排技能，在用户要求代码优化、代码清理或降噪整理时使用
disable-model-invocation: true
---

## 指令(做什么)

你仅允许执行以下代码优化技能:
- 执行技能 `/r2e-code-optimize-unused-code-symbols`
- 执行技能 `/r2e-code-optimize-unnecessary-copy`
- 执行技能 `/r2e-code-optimize-unnecessary-temporary-object`

## 约束(怎么做)

- 不允许修改源代码。
- 若用户只关心某一原子技能的结果，应优先直接调用对应原子技能。

## 输出

- 按照扫描到的每一个文件, 逐个输出结果。
- 无结果时, 输出路径
- 有结果时, 输出路径, 并输出结果，包含代码行号、问题与影响。