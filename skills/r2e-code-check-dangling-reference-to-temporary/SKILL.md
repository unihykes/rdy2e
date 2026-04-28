---
name: r2e-code-check-dangling-reference-to-temporary
description: 检查引用绑定临时对象悬垂风险，供code-check类型的agent主动调用
disable-model-invocation: true
---

## 适用场景

C++文件(h/hpp/cpp)

## 判定逻辑

- **左值/常量引用绑定到临时**后仍使用 (延续原有规则).
- **悬垂的引用/指针返回 (dangling-reference-return)**: 函数/方法返回**指向/引用局部(栈)自动变量**的指针或引用; 或返回子串、局部容器的 `data()` 等, 在调用方使用时指向已析构的存储.
- 凡「引用/指针的合法生命期不覆盖其使用点」的同类问题均归入本条.

## 示例

```cpp
const auto& s = std::string("a") + "b";
use(s);
```

```cpp
const std::string& f() { std::string t = "x"; return t; }
```

## 指令

扫描用户指定位置的代码文件, 检查上述悬垂引用/悬垂返回的风险, 并给出修复建议(具名拥有者、按值返回、延长生命期、避免返回非 static 局部地址等)
