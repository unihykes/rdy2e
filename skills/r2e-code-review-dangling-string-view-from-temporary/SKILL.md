---
name: r2e-code-review-dangling-string-view-from-temporary
description: 当用户输入 code review 时触发
disable-model-invocation: true
---

## 适用场景

C++文件(h/hpp/cpp)

## 判定逻辑

`string_view` / `span` 等不拥有内存的视图指向由临时 `std::string`、临时容器、或 `get_tmp_str()` 等返回的临时对象内部缓冲区; 临时在语句结束后销毁, 视图为悬垂

## 示例

```cpp
std::string_view sv = get_tmp_str();
use(sv);
```

## 指令

扫描用户指定位置的代码文件, 检查是否存在将 `std::string_view` / `std::span` 等绑定到临时或即将销毁的 `std::string` / 容器的值的风险, 并给出修复建议(先延长为具名 `std::string` 等拥有者, 或改为按值持有、在表达式内使用完毕等)
