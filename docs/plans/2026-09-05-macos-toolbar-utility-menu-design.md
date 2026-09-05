# macOS 悬浮状态栏工具菜单设计

## 目标

在不改动紧凑设置窗口、不复制 Windows 视觉的前提下，为 macOS 原生悬浮状态栏补齐常用工具入口。

## 交互

- 齿轮按钮打开锚定在按钮旁的原生 `NSMenu`，不创建自绘面板。
- 菜单依次提供“打开设置…”，“检查更新…”，“访问 msime.app”和“隐藏悬浮状态栏”。
- 隐藏后仍可在设置窗口重新启用悬浮状态栏。
- 菜单关闭后不抢占输入焦点，也不改变当前 composition 或候选选择。

## 边界

- `MetasequoiaFloatingToolbarPanel` 只负责菜单呈现并把动作交给当前 delegate。
- `MetasequoiaInputController` 复用现有设置、Sparkle 更新和偏好接口，并通过 `NSWorkspace` 打开官网。
- 不向设置窗口增加行、侧栏或 Windows 风格卡片。

## 验证

- 测试菜单项顺序、动作和 delegate 分发。
- 测试“隐藏”更新现有悬浮状态栏偏好。
- 构建 universal app，运行非打包测试，并用 Orca Computer 检查原生菜单的锚点和浅/深色表现。
