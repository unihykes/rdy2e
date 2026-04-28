---
name: r2e-code-check-dangling-string-view-from-temporary
description: 检查 string_view 指向临时对象的悬垂风险，供code-check类型的agent主动调用
disable-model-invocation: true
---

## 适用场景

C++文件(h/hpp/cpp)

## 判定逻辑

**Dangling `std::string_view` (悬垂 string_view)**:

- `std::string_view` 不拥有内存; 若指向由临时 `std::string`、临时容器、`get_tmp_str()` 等返回的**临时**对象内部缓冲区, 或**已 `move`/已销毁**的拥有者所曾持有的缓冲, 在语句结束或生命期结束后缓冲失效, 视图为悬垂.
- 在 `realloc`/容器收缩等可能使**引用失效**的操作之后仍持旧 `std::string_view` 亦属同类风险(若静态可推知). **`std::span` 的同类问题由技能 `/r2e-code-check-dangling-span-from-temporary` 单独检查。**

## 示例

```cpp
std::string_view sv = get_tmp_str();
use(sv);
```

## 指令

扫描用户指定位置的代码文件, 检查是否存在将 `std::string_view` 绑定到临时、已释放、已移动或即将销毁的拥有者的风险, 并给出修复建议(先延长为具名 `std::string` 等拥有者、在表达式内用完、或同步失效后的视图等)。**本技能仅负责 `std::string_view`。**
