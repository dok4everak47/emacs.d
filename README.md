# Emacs 配置 (vanilla)

手写配置，不基于 Doom/Spacemacs —— 保持轻量、可控、全中文注释。在 **Emacs 30 + macOS** 上验证。

## 这套配置解决什么

- **邮件不再开两个客户端**：Gmail + 126 两个邮箱，收信、写信、归档、补全全在 Emacs 里完成
- **Gmail 被墙也能收信**：IMAP 走不通 → mbsync 同步到本地 Maildir，Gnus 读本地，快且离线可用
- **邮件列表不再一拉一大串**：Gnus 每页 10 条 + 底部页码条点击翻页 + 最新在前
- **多个邮箱不再混在一起**：组列表按账号分组（Gmail / 126 / 草稿），一眼分清
- **编辑器不再像记事本**：VSCode 风格外观（深色主题、标签页、侧边栏文件树、行号）

## 功能一览

**邮件 (Emacs 邮件全套)**
- smtpmail 双账号发送（Gmail 走本地 socat 隧道 + 代理，126 直连），钥匙串存凭据
- 收件人 ecomplete 补全、Finder 拖拽附件、macOS 原生文件对话框
- Gnus 收件：Gmail 本地 Maildir + 126 IMAP 直连

**Gnus 体验**
- 真分页：列表只显示当前页 10 条，底部页码条鼠标点击翻页（或回车）
- 倒序显示（最新在前）、关闭线程模式保证分页精确
- 按账号 Topic 分组、Gmail 嵌套文件夹符号链接 + 自动订阅
- 列表/正文窗口固定布局、自适应不报错、启动不弹 auto-save 询问

**IDE 外观 (ide.el)**
- One Dark 主题、标签页 (tab-bar)、侧边栏文件树 (treemacs)、行号、状态栏
- 内置 eglot (LSP)、菜单栏"IDE"菜单（GUI 操作）
- Dashboard 导航页（emacs-dashboard 包）：navigator 快捷按钮（收邮件 / 写邮件 / 文件树 / 退出）+ 最近文件 + 项目列表 + 图标 + 垂直居中

**搜索与补全 (lisp/init-completion.el)**
- vertico + orderless：minibuffer 模糊搜索（空格分隔关键词，顺序无关）
- consult：`M-s g` 项目内 ripgrep 全局搜索、`M-s s` 行内搜索、`C-x b` buffer 切换带预览
- marginalia：minibuffer 条目右侧注解（文件大小、函数描述等）
- embark：`C-.` / `M-o` 光标处上下文操作（类似 VSCode 右键菜单）
- corfu + cape：代码补全弹窗（自动触发、模糊匹配、Tab 接受）

**开发工具 (lisp/init-tools.el)**
- which-key：按下前缀键后弹出可用按键列表，不用背快捷键
- magit：`C-x g` 打开 Git 客户端（diff 按词高亮）
- diff-hl：左侧 gutter 实时显示 git 变更标记（新增/修改/删除）

**环境集成 (lisp/init-env.el)**
- exec-path-from-shell：从 shell 继承 PATH（nix/homebrew 命令在 GUI Emacs 可用）
- envrc：direnv 集成（.envrc 项目自动加载环境变量）
- yasnippet + yasnippet-snippets：代码片段模板展开
- treesit-auto：自动安装 tree-sitter 语法包，高亮/缩进更精准

**其他**
- 终端里 Option 键 = Meta（Terminal.app / iTerm2 均已配置）
- 邮件导航菜单：菜单栏点"返回所有邮箱"，不用记快捷键
- server-start：允许 emacsclient 远程连接
- M-x shell 使用 bash 5.3（nix），非 macOS 自带 3.2

## 安装

```bash
git clone https://github.com/dok4everak47/emacs.d.git ~/.emacs.d
```

首次启动会自动从清华 ELPA 镜像安装缺失的包（doom-themes / treemacs / mood-line / dashboard / nerd-icons / vertico / consult / corfu / magit 等）。

安装后执行 `M-x nerd-icons-install-fonts` 安装图标字体（一次性）。

依赖环境：Emacs 30+、macOS、ClashX 代理（Gmail 发送隧道）、macOS 钥匙串凭据（smtp.gmail.com / smtp.126.com）。

## 文件结构

| 文件 | 作用 |
|---|---|
| `init.el` | 主配置：邮件 + Gnus + 导航 + 诊断 + 模块加载 |
| `early-init.el` | 启动早期配置（关闭 native 编译避免刷屏） |
| `ide.el` | VSCode 外观层 + Dashboard 导航页 + package.el 初始化 |
| `lisp/init-completion.el` | 搜索与补全：vertico / consult / orderless / marginalia / embark / corfu |
| `lisp/init-tools.el` | 开发工具：which-key / magit / diff-hl |
| `lisp/init-env.el` | 环境集成：exec-path-from-shell / envrc / yasnippet / treesit-auto |

## 注意

- 邮箱凭据在 macOS 钥匙串，不在此仓库
- 想还原默认外观：删除 `ide.el` 和 `init.el` 末尾模块加载段
