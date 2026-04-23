---
name: r2e-code-review-dangling-lambda-capture-by-reference
description: 当用户输入 code review 时触发
disable-model-invocation: true
---

## 适用场景

C++文件(h/hpp/cpp)

## 判定逻辑

lambda 按引用捕获局部变量, 但 lambda 的生命周期长于该局部变量; 常见形态为通过 `[&x](){...}` 将 lambda 交给线程、异步回调、定时器或长生命周期持有者, 在局部已销毁后仍可能执行

## 示例

```cpp
int x = 0;
std::thread([&x]() { use(x); }).detach();
```

## 指令

扫描用户指定位置的代码文件, 检查是否存在按引用捕获局部(或等效于引用局部)的 lambda 被延长生命周期使用的风险, 并给出修复建议(例如按值捕获、将数据移入 `shared_ptr`、或确保同步与作用域)
