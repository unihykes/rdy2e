---
name: r2e-code-check-virtual-call-in-constructor
description: 检查构造阶段虚调用风险，供code-check类型的agent主动调用
disable-model-invocation: true
---

## 适用场景

C++文件(h/hpp/cpp)

## 判定逻辑

构造/析构中经虚分派调用了本类的多态接口: 在对象尚未完成构造或已开始析构时, 对 **virtual 成员** 的 **非静态绑定** 调用, 不会落到派生类重载(若预期为派生行为则属隐患).

## 精准底线(同时满足才标记, 控制误报)

1. **位置**: 调用发生在**构造函数**或**析构函数**体内(含其直接/间接调用的、仍属构造/析构语义的实现路径, 以审查工具可判定为准).
2. **对象**: 被调用的成员函数在该类声明中是 **virtual**(含 `override` 的虚重载, 以及构成虚分派的接口).
3. **方式**: 调用**没有**用**类名显式限定**(即不是 `Base::func()` 形式, 该形式为静态分派, 不属本条风险).

**不标记(排除)**:

- 调用的**不是** `virtual` 成员函数: 不触发虚分派问题.
- 使用**类名限定**调用 `virtual` 成员, 例如 `Base::virtual_func()`: 开发者有意静态分派, **不**报警.

## 示例(应被本规则覆盖的典型形态)

```cpp
struct Base {
  Base() { init(); }  // 若 init 为 virtual 且未用 Base::init() 则命中
  virtual void init() {}
  virtual ~Base() { cleanup(); }
  virtual void cleanup() {}
};
```

## 指令

扫描用户指定位置的代码文件, 仅当同时满足上述三条底线时报告问题, 并建议改为非虚辅助函数、类名限定的 `Base::f()` 调用、或 CRTP/两阶段初始化等可审计的替代设计
