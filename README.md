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
- One Dark 主题、标签页 (tab-bar)、侧边栏文件树 (dired-sidebar)、行号、状态栏
- lsp-mode + lsp-ui（PHP/Python/JS/TS/Rust 自动启动；nix 走内置 eglot + nixd）、菜单栏"IDE"菜单（GUI 操作）
- Dashboard 导航页（emacs-dashboard 包）：navigator 快捷按钮（邮件 / 文件树 / 退出 / agenda / capture …）+ 2x2 分区（上排 Recent Files · Projects，下排 Agenda · Bookmarks，窗口 <54 列自动退回单列）+ Nerd 图标 + 垂直居中；agenda 卡由子进程异步刷新，万一卡住可 `M-x my-dash-agenda-refresh` 手动重来

**搜索与补全 (lisp/init-completion.el)**
- vertico + orderless：minibuffer 模糊搜索（空格分隔关键词，顺序无关）
- consult：`M-s g` 项目内 ripgrep 全局搜索、`M-s s` 行内搜索、`C-x b` buffer 切换带预览
- marginalia：minibuffer 条目右侧注解（文件大小、函数描述等）
- embark：`C-.` / `M-o` 光标处上下文操作（类似 VSCode 右键菜单）
- corfu + cape：代码补全弹窗（自动触发、模糊匹配、Enter 确认候选；Tab 不接受候选 —— snippet 占位符内跳字段，其余情况交给 yas 展开 / mode 缩进）

**开发工具 (lisp/init-tools.el)**
- which-key：按下前缀键后弹出可用按键列表，不用背快捷键
- magit：`C-x g` 打开 Git 客户端（diff 按词高亮）
- diff-hl：左侧 gutter 实时显示 git 变更标记（新增/修改/删除）
- diredfl + dired-subtree：按文件类型着色、`i` 展开子树（macOS 的 BSD ls 不兼容 GNU 开关，改用 ls-lisp 绕开）
- windmove：`⌘ + 方向键` 切窗口、`⌘⇧ + 方向键` 调窗口大小、`C-c w` 列出所有窗口来选

**环境集成 (lisp/init-env.el)**
- exec-path-from-shell：从 shell 继承 PATH（nix/homebrew 命令在 GUI Emacs 可用）
- envrc：direnv 集成（.envrc 项目自动加载环境变量）
- yasnippet + yasnippet-snippets：代码片段模板展开
- treesit-auto：自动安装 tree-sitter 语法包，高亮/缩进更精准

**内嵌终端 (lisp/init-term.el)**
- vterm：C 实现的高速终端模拟器（替代 VSCode 内置终端）
- `C-c v` 当前窗口打开终端、`C-c V` 新窗口打开
- 退出自动关 buffer、10000 行回滚、copy-mode 快速滚动

**开发辅助 (lisp/init-dev.el)**
- flymake：Emacs 29+ 内置实时语法检查（fringe + margin 标记，`M-g n`/`M-g p` 跳转，`C-c ! l` 错误列表）
- impatient-mode + simple-httpd：HTML/CSS 实时预览（编辑即刷新，替代 VSCode Live Server，`localhost:8080`）

**模态编辑 (lisp/init-meow.el)**
- meow：Kakoune 式「先选中再操作」（2026-08 从 evil 迁来），`M-x meow-tutor` 15 分钟上手，`SPC ?` 随时翻键位表
- 不接管 major-mode 键位：没被占用的键穿透到原生 keymap，所以各 mode 的原有快捷键直接可用
- `SPC` 是 keypad 万能前缀（`SPC x f` = `C-x C-f`），未命中会透明转发到 `C-c`
- 自定义 state：`emacs`（Gnus 等纯原生场景）、`org-agenda`（agenda 专用键位）
- 环绕操作用 surround 包：`SPC s s` / `d` / `c`

**Org Mode (lisp/init-org.el)**
- org 核心设置：缩进对齐、隐藏前导星号、TODO 状态流转（TODO→DOING→HOLD→DONE/CANC）
- org-capture 快速捕获：`C-c c` 弹模板菜单（任务/笔记/链接/日记/主题笔记）；主题笔记是唯一会新建文件的模板（提示文件名后写入 `#+TITLE` 骨架）
- 笔记总入口：`C-c i` 列出 ~/org 下所有主题笔记（一个主题一个文件），选中即打开；选「＋ 新建主题…」走 capture `N` 建新主题，选「⌂ 全部主题一览」打开自动生成的 index.org；`C-c I` 直接翻那份索引页（打开前自动重建）
- org-agenda 日程总览：`C-c a` 跨文件查看所有 TODO 和日程
- GTD 周回顾（`C-c a R`）一次拉齐 6 张清单：本周日程 → 行动池（自动排除 habits.org 的重复习惯）→ 等待中 → 僵死项目（`org-stuck-projects` 判据：带 `:project:` 标签的一级标题、子树里没有任何非关闭 TODO）→ 全部项目 → 将来也许；`C-c a i` 是收件箱清零视图，只扫 inbox.org
- 任务收集只有一个入口：`C-c c t` 落 `inbox.org`，整理时 `C-c C-w` 归位到 `projects.org`；`notes.org` 只放笔记不放任务（2026-09-28 清理了它与 inbox 的三条重复任务）
- org-babel 文学编程：代码块可直接执行（Python / Shell / Emacs Lisp）
- org-modern 现代外观：符号替代星号、TODO 关键字彩色背景
- org 智能命令走 `SPC` 前缀（`SPC i/a/o/O/d/x` 表感知插入、列表延续、智能删除；`SPC [/]/{/}` element 与段落跳转），全部集中在 init-org.el
- 归档落点统一进 `~/org/archive.org` 的日期树（`org-archive-location`），完成的项目 `C-c C-x C-a` 归档后不再出现在周回顾的「僵死项目」里

**快捷工具 (lisp/init-lazycat.el)**
- super-save 停手 1 秒自动保存、vundo 可视化撤销树（`C-x u`）、symbol-overlay 符号高亮与一键重命名（`C-c s` 前缀）
- popper 临时弹窗管理（`C-c p p`）、olivetti 写作居中（`C-c o o`）、pangu-spacing 中英文自动加空格、move-text 整行上下移
- markdown-mode：Emacs 内 live preview（`C-c C-c l`，eww 渲染，右侧并排）

**Nix / 缩进 / 括号 (init-nix.el · init-simple-indent.el · init-paren.el)**
- nix-mode + nixd（eglot）+ nixfmt 保存自动格式化；nix 刻意排除 treesit（缩进不如 SMIE 稳）
- 所有 prog-mode 统一 TAB 缩进 2 空格、RET 继承当前行缩进（再按一次回车取消缩进）
- rainbow-delimiters + highlight-parentheses（Lisp 系）+ show-paren（其他语言）；光标在空括号对中间按退格一次删整对

**远程服务器 (lisp/init-server.el)**
- TRAMP 远程文件/目录 + vterm SSH；清单在私有文件 `servers.el`（不入库）
- `M-x my-server-dired` / `my-server-vterm` / `my-server-browse-files`，或直接 `C-x C-f /ssh:别名:/路径`

**生活质感补丁 (lisp/init-qol.el)**
- no-littering：backup / auto-save 集中到 `~/.cache/emacs`，不再污染项目目录
- undo-fu-session：撤销历史跨重启（不动键位，meow 的 u / vundo 照旧）
- apheleia：保存时自动格式化（nix 除外，该语言已由 eglot→nixd→nixfmt 负责）
- vterm-toggle：`C-c T` 从底部弹出/收起终端（与 `C-c v` / `C-c V` 并存）
- ace-window `C-x o` 选窗口、avy `M-g c/w/l` 字符跳转
- elfeed：`C-c j` RSS 阅读，订阅清单 `elfeed.org`（已 gitignore）

**其他**
- 终端里 Option 键 = Meta（Terminal.app / iTerm2 均已配置）
- 邮件导航菜单：菜单栏点"返回所有邮箱"，不用记快捷键
- server-start：允许 emacsclient 远程连接
- M-x shell 使用 bash 5.3（nix），非 macOS 自带 3.2

## 安装

```bash
git clone https://github.com/dok4everak47/emacs.d.git ~/.emacs.d
```

首次启动会自动从清华 ELPA 镜像安装缺失的包（doom-themes / dired-sidebar / mood-line / dashboard / nerd-icons / vertico / consult / corfu / meow / magit / lsp-mode / impatient-mode 等）。

安装后执行 `M-x nerd-icons-install-fonts` 安装图标字体（一次性）。

依赖环境：Emacs 30+、macOS、ClashX 代理（Gmail 发送隧道）、macOS 钥匙串凭据（smtp.gmail.com / smtp.126.com）、cmake（vterm 编译，`brew install cmake`）。

## 文件结构

| 文件 | 作用 |
|---|---|
| `early-init.el` | 启动早期配置（关闭 native 编译避免刷屏） |
| `init.el` | 主配置：邮件（发送 + Gnus 收件）+ 诊断 + 主装配（模块加载顺序在文件末尾） |
| `ide.el` | VSCode 外观层 + Dashboard 导航页 + package.el 初始化 |
| `lisp/init-completion.el` | 搜索与补全：vertico / consult / orderless / marginalia / embark / corfu |
| `lisp/init-tools.el` | 开发工具：which-key / magit / diff-hl / diredfl / dired-subtree / windmove |
| `lisp/init-env.el` | 环境集成：exec-path-from-shell / envrc / yasnippet / treesit-auto |
| `lisp/init-nix.el` | Nix 语言：nix-mode + nixd（eglot）+ nixfmt |
| `lisp/init-term.el` | 内嵌终端：vterm（C 实现高速终端） |
| `lisp/init-server.el` | 远程服务器：TRAMP + vterm SSH（清单在 servers.el） |
| `lisp/init-dev.el` | 开发辅助：flymake 语法检查 / impatient-mode 实时预览 |
| `lisp/init-simple-indent.el` | 统一缩进：TAB 2 空格 / RET 继承缩进 |
| `lisp/init-paren.el` | 括号可视化：rainbow-delimiters / highlight-parentheses / show-paren |
| `lisp/init-meow.el` | 模态编辑：meow + surround + 自定义 state（emacs / org-agenda） |
| `lisp/init-org.el` | Org Mode：笔记/任务/文学编程/capture/agenda |
| `lisp/init-lazycat.el` | 快捷工具：super-save / vundo / symbol-overlay / popper / olivetti / markdown 预览 |
| `lisp/init-qol.el` | 生活质感补丁：no-littering / undo-fu-session / apheleia / vterm-toggle / ace-window / avy / elfeed |

## 注意

- 邮箱凭据在 macOS 钥匙串，不在此仓库
- 想还原默认外观：删除 `ide.el` 和 `init.el` 末尾模块加载段
