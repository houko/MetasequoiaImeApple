# MSIME-Apple

组织职责见 [组织规范](https://github.com/metasequoiaime/.github/blob/main/AGENTS.md)。平台代码负责 InputMethodKit/UIKit、焦点和系统文本插入；输入算法使用固定 Engine InputSession。

桌面词库使用 product-lock.json 的已发布数据及摘要。`tools/MetasequoiaImeDict` 是移动产品构建工具的独立版本，不代表这些已发布数据的源版本。iOS 先获取同一锁定数据库，再调用该工具的公开 mobile profile；禁止在 Apple 复制压缩/分表算法。词库格式验证器从固定 Engine 复制，CI 比较字节防止漂移。
