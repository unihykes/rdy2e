# r2e

**r2e = Ready to Eat**

这是一个给 Cursor 使用的插件仓库：把规则（rules）和技能（skills）预先封装好，安装后即可使用。  
`r2e` 的含义是“开袋即食”——对应工程语境就是“开箱即用”。

---

## 概述

在很多团队里，AI 编程能力并不是缺模型，而是缺一套可复用、可传播、可维护的行为标准。  
r2e 想解决的就是这个问题：把散落在对话里的经验，沉淀为可版本化的插件资产。

- **Ready**：规则与技能已预设，不用每次重新解释
- **To Eat**：拿到就能用，减少初始化和对齐成本
- **For Teams**：支持跨仓库复用，保持一致工程行为

一句话：**把 AI 经验做成“即食插件”。**

---

## 仓库内容

- `rules/`：持久生效的约束与规范（`.mdc`）
- `skills/`：可调用的任务能力（`SKILL.md`）
- `install.bat`：安装脚本（无参安装到全局，带参安装到指定项目）
- `uninstall.bat`：卸载脚本（无参卸载全局，带参卸载指定项目）

---

## 安装方式

### 1. 安装到全局（当前用户）

```bat
install.bat
```

默认安装到：
`%USERPROFILE%\.cursor\plugins\local\r2e`

### 2. 安装到指定项目

```bat
install.bat "Z:\xxx_path\your_project_path"
```

会安装到：
`<项目路径>\.cursor\plugins\local\r2e`

### 3. 卸载（全局 / 指定项目）

卸载全局（当前用户）：

```bat
uninstall.bat
```

卸载指定项目：

```bat
uninstall.bat "Z:\xxx_path\your_project_path"
```

---

## 生效与验证

安装后重启 Cursor 即可生效。

然后在 Cursor 的 Rules/Skills 中确认对应组件已加载即可。
