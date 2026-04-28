---
name: r2e-code-check-empty-container-access
description: 检查空容器访问风险，供code-check类型的agent主动调用
disable-model-invocation: true
---

## 适用场景

C++文件(h/hpp/cpp)

## 判定逻辑

**对明确为空的容器取首末元 (empty-container-access)**: 在**可静态判定**的同一控制流上, 已调用 `empty()` 为真(或等价的 `size() == 0` / 默认构造立即使用)仍调用 `front()` / `back()` / 解引用 `begin()` 前未与 `end()` 区分等.

**不标记**: 有非空检查间隔且工具无法证明仍为空, 或仅先 `resize`/`insert` 再 `front` 的合法序.

## 指令

扫描用户指定位置的代码文件, 在空容器可判的前提下检查 `front`/`back` 等越界前访问, 并建议先判空、用 `if (!v.empty())`、`optional` 式访问或 `at()` 等
