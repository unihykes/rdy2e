---
name: r2e-code-check
description: C++ 代码检查，在用户要求 code check 或代码审查时使用
disable-model-invocation: true
---

## 指令(做什么)

你仅允许执行以下代码检查技能:
- 执行技能 `/r2e-code-check-use-after-move`
- 执行技能 `/r2e-code-check-virtual-call-in-constructor`
- 执行技能 `/r2e-code-check-dangling-reference-to-temporary`
- 执行技能 `/r2e-code-check-dangling-string-view-from-temporary`
- 执行技能 `/r2e-code-check-dangling-span-from-temporary`
- 执行技能 `/r2e-code-check-dangling-lambda-capture-by-reference`
- 执行技能 `/r2e-code-check-shared-ptr-constructed-from-this`
- 执行技能 `/r2e-code-check-null-dereference-when-nullable`
- 执行技能 `/r2e-code-check-empty-container-access`
- 执行技能 `/r2e-code-check-out-of-bounds-access-statically-known`
- 执行技能 `/r2e-code-check-integer-divide-by-zero-when-denominator-statically-known`
- 执行技能 `/r2e-code-check-sensitive-data-exposure`

## 约束(怎么做)

- 不允许修改源代码。
- 若用户只关心某一原子技能的结果，应优先直接调用对应原子技能。

## 输出

- 按照技能类别向调用方输出结果，包含各检查项的结论、问题与建议。
- 代码位置需要明确到具体的文件和行号。
- 检查结果无问题时无需输出。

- 按照扫描到的每一个文件, 逐个输出结果。
- 无结果时, 输出路径
- 有结果时, 输出路径, 并输出结果，包含代码行号、问题与影响。