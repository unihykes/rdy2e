---
name: r2e-code-check-out-of-bounds-access-statically-known
description: 当用户输入 code check 时触发
disable-model-invocation: true
---

## 适用场景

C++文件(h/hpp/cpp)

## 判定逻辑

**越界访问 (out-of-bounds)**: 在**下标/迭代器差分可静态估计**的范围内(定长 `std::array`、栈数组、`vector`+字面量常量下标、C 串已知长度+常量下标等), 索引/指针偏移**已证明** `>=` size 或 `<0`.

对完全依赖**运行时**变量的索引用 `at()` 的意图或无法证明越界, 不强行标记(可减少误报).

## 指令

扫描用户指定位置的代码文件, 在静态可判的数组/容器/SIMD/缓冲区访问上检查索引是否越界, 并建议改用 `at`、先比较 `size`、用 `std::array`+编译期界、`span`+子域、或修正下标常量
