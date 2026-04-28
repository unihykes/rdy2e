---
name: r2e-code-check-dangling-span-from-temporary
description: 当用户输入 code check 时触发
disable-model-invocation: true
---

## 适用场景

C++文件(h/hpp/cpp)

## 判定逻辑

**Dangling `std::span` (悬垂 span)**:

- `std::span` 不拥有内存，仅引用连续元素；若其指向由**临时** `std::vector`、临时数组包装、`get_tmp_buffer()` 等返回的**临时**对象内部缓冲，或**已 `move`/已销毁**的拥有者曾持有的缓冲，在语句结束或生命期结束后缓冲失效，则 `span` 为悬垂。
- 在 `realloc`/容器收缩等可能使**引用失效**的操作之后仍持旧 `std::span` 亦属同类风险(若静态可推知)。

## 示例

```cpp
std::span<const int> s = get_tmp_vec();
use(s);
```

## 指令

扫描用户指定位置的代码文件，检查是否存在将 `std::span` 绑定到临时、已释放、已移动或即将销毁的拥有者的风险，并给出修复建议(先延长为具名拥有容器、在表达式内用完、或同步失效后的 `span` 等)。**本技能仅负责 `std::span`；`std::string_view` 由技能 `/r2e-code-check-dangling-string-view-from-temporary` 覆盖。**
