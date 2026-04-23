---
name: r2e-code-check-dangling-reference-to-temporary
description: 当用户输入 code check 时触发
disable-model-invocation: true
---

## 适用场景

C++文件(h/hpp/cpp)

## 判定逻辑

临时对象被引用绑定，随后使用

## 示例

```cpp
const auto& s = std::string("a") + "b";
use(s);
```

## 指令

扫描用户指定位置的代码文件, 检查是否存在将左值/常量引用绑定到临时对象、后续仍使用该引用的风险, 并给出修复建议
