# 书签折角 · Dogear Style

A [KOReader](https://github.com/koreader/koreader) plugin that customizes the bookmark dogear (page-corner fold) icon and size.

一个 KOReader 插件：自定义书签折角（dogear）的图标与大小。

## 功能 Features

- **自动大小**：沿用 KOReader 原生逻辑，折角不超过页边距、不压住正文。
- **自定义大小**：按屏幕宽度（横边）的百分比计算，2% – 40%。
- **预设档位**：3% / 6% / 12% / 20% / 30%。
- **图标可替换**：直接替换 `dogearstyle.koplugin/icons/dogear.svg`。

## 安装 Installation

1. 下载 `dogearstyle.koplugin.zip` 并解压，得到 `dogearstyle.koplugin` 文件夹（里面直接是 `main.lua`，**不要**嵌套一层同名文件夹）。
2. 把整个文件夹放入 KOReader 的插件目录：
   - Android：`/sdcard/koreader/plugins/`
   - Kobo：`.adds/koreader/plugins/`
   - Kindle / 其它：`koreader/plugins/`
3. 完全退出并重启 KOReader（插件只在启动时加载）。

## 使用 Usage

1. 打开一本书（插件仅在阅读界面生效）。
2. 点顶部菜单 → 主菜单列表**最底部** → “新：书签折角”。
3. 选择大小：
   - **自动大小（不压住文字）**：沿用原生逻辑，折角不遮挡正文；
   - **大小：3% / 6% / 12% / 20% / 30%**：按屏幕宽度百分比；
   - **自定义大小…**：2% – 40% 精细调节（当前值会显示在菜单项上）。

## 自定义图标 Custom icon

将 `dogearstyle.koplugin/icons/dogear.svg` 替换为你自己的 SVG（保持文件名 `dogear.svg` 即可）。

> 建议使用**内联属性**写法（`fill` / `stroke` 直接写在元素上），避免 `<style>` 内嵌 CSS 类。KOReader 使用 MuPDF 渲染 SVG，对内嵌 CSS 类选择器的支持不完整，样式可能不生效。

## 兼容性 Compatibility

本插件通过给 KOReader 的 `ReaderDogear` 模块打补丁实现，依赖其内部结构（`self[1]` / `top_pad` / `vgroup` / `icon`）。KOReader 版本升级后这些内部结构可能变化，导致折角样式或大小不生效；此时菜单仍可正常使用，只是视觉效果退回原生。

如遇问题，请提交 Issue，并附上 `crash.log`（KOReader 设置 → 关于 → 报告问题，或直接读取 `koreader/crash.log`）中与 `dogearstyle` 相关的日志。
