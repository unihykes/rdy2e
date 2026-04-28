---
name: r2e-code-check-null-dereference-when-nullable
description: 检查可空对象空指针解引用风险，供code-check类型的agent主动调用
disable-model-invocation: true
---

## 适用场景

C++文件(h/hpp/cpp)

## 判定逻辑

**空指针解引用 (null-dereference)**: 在**可静态判定**的同一作用域/路径上, 指针(含 `T*`、智能指针的 `get()`、可选未检查解引用)已判空/可能为空仍**解引用、成员访问、下标**; 或先判真分支使用却在另一分支**隐式**假定非空(矛盾路径).

在无法静态区分的**动态**真值, 不强行标记; 仅对明显矛盾或缺省检查的路径报告.

## 指令

扫描用户指定位置的代码文件, 在可静态推知的空路径上检查是否仍解引用, 并给出修复建议(先检查再使用、`return`/早退、使用 `if (p)` 合一、`std::optional`/引用类型、断言仅用于非生产假设等)
