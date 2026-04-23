---
name: r2e-code-review-use-after-move
description: 当用户输入 code review 时触发
disable-model-invocation: true
---

## 适用场景

C++文件(h/hpp/cpp)

## 指令

扫描用户指定位置的代码文件, 检查是否存在使用后移动的风险, 并给出修复建议
