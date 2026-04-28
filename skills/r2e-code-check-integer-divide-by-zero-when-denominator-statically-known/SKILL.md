---
name: r2e-code-check-integer-divide-by-zero-when-denominator-statically-known
description: 检查静态可判定整数除零风险，供code-check类型的agent主动调用
disable-model-invocation: true
---

## 适用场景

C++文件(h/hpp/cpp)

## 判定逻辑

**整除取模零除 (divide-by-zero)**: 在**可静态推知**分母为 0(字面量 0, 经常量折叠为 0, 与零相等的已定义枚举/常量)时仍执行**整数除法或取模**; `INT_MIN / -1` 等**实现定义但有界**的陷阱若项目关心可一并报告.

**不标记**: 分母为仅运行时量且无任何静态 0 证明(除非有明确 `assert(分母 != 0)` 前的矛盾路径, 可酌情报告).

## 指令

扫描用户指定位置的代码文件, 在分母为静态 0 或可常量化简为 0 的表达式上检查 `/` 与 `%`, 并建议先检零、用早退、或使类型/约束保证非零
