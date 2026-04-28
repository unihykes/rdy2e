---
name: r2e-code-check-shared-ptr-constructed-from-this
description: 检查直接用 this 构造 shared_ptr 风险，供code-check类型的agent主动调用
disable-model-invocation: true
---

## 适用场景

C++文件(h/hpp/cpp)

## 判定逻辑

**shared-ptr-from-this 误用**: 在未继承 `std::enable_shared_from_this` 的类(或等效不建立与已有控制块关联)的**成员函数/友元**中, 用**裸 `this` 构造** `std::shared_ptr` 或经 `std::make_shared` 以 `this` 为**非由自身分配**的指针, 会产生**与外部已有 `shared_ptr` 无关的第二个控制块**, 导致**双重析构/双重释放**; 对尚未由 `std::shared_ptr` 接管的 `this` 上调用 `shared_from_this()` 可能未定义或抛异常.

**不标记(排除)**: 类**公开继承** `std::enable_shared_from_this`, 且**先**由 `shared_ptr` 拥有该对象, 再使用 `shared_from_this()` 的合法模式.

## 指令

扫描用户指定位置的代码文件, 检查是否存在在不适用的类型上从 `this` 直造 `shared_ptr` 或误用 `shared_from_this` 的风险, 并建议 `enable_shared_from_this`+工厂、统一由 `shared_ptr` 入口创建、或弱引用等
