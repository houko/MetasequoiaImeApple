# MSIME-Apple

组织职责见 [组织规范](https://github.com/metasequoiaime/.github/blob/main/AGENTS.md)。平台代码负责 InputMethodKit/UIKit、焦点和系统文本插入；输入算法使用固定 Engine InputSession。

桌面词库使用 product-lock.json 的已发布数据及摘要。`vendor/MetasequoiaImeEngine` 同时提供输入引擎、`helpcode/helpcodes/` 和根 `build_profile.py` 移动构建入口；禁止另行检出 Dict/HelpCode 或在 Apple 复制数据算法。Engine gitlink 与已发布词库源提交仍分别记录，不能把构建器提交冒充下载数据的来源。词库格式验证器从固定 Engine 复制，CI 比较字节防止漂移。
