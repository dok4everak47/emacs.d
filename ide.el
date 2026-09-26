;;; ide.el — VSCode 风格 IDE 外观层 -*- lexical-binding: t -*-
;;;
;;; 独立于邮件配置 (init.el)。不想要时: 删掉本文件 + init.el 末尾两行即可还原。
;;; 依赖: 网络可访问清华 ELPA 镜像 (首次加载自动安装缺失包)。
;;; 注意: 本文件不启用 native-comp (见 early-init.el), 包走字节码, 功能不受影响。

;; 编译期声明 (包/内置模块加载后变量才有定义)
(defvar display-line-numbers-type nil)
(defvar org-agenda-window-setup)   ; org 包的 defcustom, 声明为 special 供 let 动态绑定
(defvar org-agenda-sticky)
(declare-function dired-sidebar-toggle-sidebar "dired-sidebar")
(declare-function dired-sidebar-jump-to-sidebar "dired-sidebar")
(declare-function mood-line-mode "mood-line")
(declare-function dashboard-setup-startup-hook "dashboard")
(declare-function doom-themes-visual-bell-config "doom-themes")

;; ---------- 包管理: 内置 package.el + 清华镜像 ----------
(require 'package)
(setq package-archives
      '(("gnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
        ("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
        ("melpa" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))
;; 启动优化 (2026-09-23): 这里不再调 (package-initialize)。
;; 实测: 进入本文件时 package--activated 已是 t, package-alist 已有 92 个包
;; (Emacs 27+ 在 init.el 之前就按 package-enable-at-startup 激活完毕),
;; 这行只是重复扫描 elpa 目录, 白花 0.128s。
;; 警告: 若哪天把 package-enable-at-startup 设成 nil, 这里必须改回 (package-activate-all)。
(require 'use-package)
(setq use-package-always-ensure t)

;; ---------- 主题: One Dark (VSCode Dark+ 同款配色) ----------
(use-package doom-themes
  :config
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)
  (load-theme 'doom-one t)
  ;; 可视化错误提示 (闪屏替代蜂鸣声)
  (doom-themes-visual-bell-config))

;; ---------- 字体 (SpaceMono Nerd Font Mono: SpaceMono + Nerd 图标, Mono 变体保证等宽) ----------
(set-face-attribute 'default nil :family "SpaceMono Nerd Font Mono" :height 180)

;; 中文字体: 西文字体 (SpaceMono Nerd Font Mono) 没有中文字形, Emacs 会自动 fallback
;; 到系统默认中文字体, 导致中英文风格不统一。
;; 指定 fontset: 汉字/日文假名/谚文等 CJK 字符用苹方 (PingFang SC, macOS 内置)。
;; 想换其他中文字体, 改 "PingFang SC" 即可 (如 "Songti SC" 宋体 / "Heiti SC" 黑体)。
(dolist (charset '(kana han cjk-misc bopomofo))
  (set-fontset-font t charset (font-spec :family "PingFang SC")))

;; ---------- 标签页 (浏览器式: 每个 buffer 一个 tab, 点击切换) ----------
;; tab-bar-buffers: 把 tab-bar 的 tab 内容来源改成 buffer (每打开 buffer 一 tab,
;; 点 tab 切 buffer, 关 buffer 关 tab), 比 Emacs 默认的 tab (窗口布局快照) 直观。
;; ⚠️ tab-bar-buffers-mode 不会自动开 tab-bar-mode — 必须两个都开, 否则那一栏不显示。
(tab-bar-mode 1)
(tab-bar-buffers-mode 1)

;; ⚠️ tab-bar-buffers 默认按 buffer 名字母序排 tab → C-x 方向键跳转无规律。
;; 改成 buffer-list 顺序 (= 打开顺序, 最近激活的排最前), 切 tab 可预期。
(advice-add 'tab-bar-buffers--interesting-buffers--sort
            :override
            (lambda () (tab-bar-buffers--interesting-buffers)))

;; ⚠️ 排除 .org 文件 buffer 不进 tab-bar: 打开 agenda (C-c a) 时 org 会
;; 把 ~/org/ 下所有文件读进 buffer, tab-bar-buffers 每个 buffer 一个 tab,
;; 导致一堆 org 文件 tab。org 文件用 C-x b / dired 访问, 不需进 tab。
;; 用 :around advice 拦截 interesting-buffer-p, .org 一律 nil。
(defun my-tbb-hide-org-around (orig buffer)
  (if (and (bufferp buffer) (buffer-name buffer)
           (string-suffix-p ".org" (buffer-name buffer)))
      nil
    (funcall orig buffer)))
(advice-add 'tab-bar-buffers--interesting-buffer-p :around #'my-tbb-hide-org-around)

;; ---------- 窗口分屏方向 (Dired o / find-file-other-window 等) ----------
;; split-window-sensibly 规则: 窗口 >= split-width-threshold 字符宽 → 左右分;
;; 否则 >= split-height-threshold 行高 → 上下分; 都够不着且是唯一窗口 → 往下劈。
;; 默认 160 太宽, 普通帧永远左右不了, 只能上下堆叠。调到 90: 够宽就左右并排。
(setq split-width-threshold 90)

;; ---------- 侧边栏文件树 (dired-sidebar, VSCode 左侧 Explorer) ----------
;; dired-sidebar: 把 dired 放进侧边窗口, 天然继承 dired 全部键位 (i/TAB
;; 子树, C-x M-o dotfiles, g 刷新, wdired C-x C-q), 无需学新键。
;; 项目根检测走 projectile (dired-sidebar-project-root-fn 设为
;; dired-sidebar-project-root-projectile), projectile-after-switch-project-hook
;; 自动挂 → C-c p p 切项目 sidebar 自动刷新根目录。
;; meow: dired-sidebar-mode 继承 dired-mode → 已映射 motion 态, 无需配置。
;; ⚠️ 不用包自带的 dired-sidebar-project-root-projectile: 它在非项目 buffer
;; (dashboard/scratch) 里 projectile-project-root 返回 nil → expand-file-name
;; 报 "Wrong type argument: stringp, nil" (2026-08 实测 C-c t t 报错)。
;; 自定义 wrapper 兜底回退 default-directory。
(defun my-dired-sidebar-project-root ()
  "项目根: projectile 命中返回项目根; 否则回退当前目录 (防 nil 报错)."
  (or (when (fboundp 'projectile-project-root)
        (projectile-project-root))
      default-directory))
(use-package dired-sidebar
  :ensure t
  :demand t                                 ; :custom 变量需包加载才定义
  :after projectile                          ; 等 projectile 加载后配 root-fn
  :bind
  (;; 打开/收起侧边栏 (treemacs 同款 C-c t t)
   ("C-c t t" . dired-sidebar-toggle-sidebar)
   ;; 选中侧边栏窗口
   ("C-c t d" . dired-sidebar-jump-to-sidebar))
  :custom
  (dired-sidebar-width 28)
  (dired-sidebar-theme 'nerd-icons)         ; 文件图标 (nerd-icons 已装)
  (dired-sidebar-should-follow-file nil)    ; 不自动跟随 (流畅优先, 同 treemacs 教训)
  (dired-sidebar-refresh-on-project-switch t) ; 切项目时自动刷新根目录
  (dired-sidebar-close-sidebar-on-file-open nil) ; 打开文件后树保留
  (dired-sidebar-pop-to-sidebar-on-toggle-open nil) ; toggle 打开时不抢焦点
  (dired-sidebar-project-root-fn #'my-dired-sidebar-project-root)) ; 走 projectile (见下方)

;; ---------- dired 增强 (C-x d 原生 + C-x D 选目录) ----------
;; 双命令分工, 各司其职:
;; - C-x d: 原生 dired, 直接敲路径/补全进目录 — 符合肌肉记忆, 快速浏览。
;; - C-x D: consult-dir 弹候选选目录 (历史/项目/recentf/bookmark) 后进 dired —
;;   需要跳历史路径或项目根时用. 窄化: p=项目 r=recentf h=输入历史 .=当前.
(defun my-dired-choose ()
  "选择目录后打开 dired (候选含项目根/项目/历史/最近目录)."
  (interactive)
  (require 'consult-dir)
  (let ((consult-dir-default-command #'dired))
    (call-interactively #'consult-dir)))
(global-set-key (kbd "C-x D") #'my-dired-choose)

;; ---------- 文件图标 (nerd-icons-dired, dired-sidebar 依赖) ----------
(use-package nerd-icons-dired
  :ensure t
  :hook (dired-mode . nerd-icons-dired-mode))

;; ---------- projectile (项目管理, 替代内置 project.el) ----------
;; consult-projectile 提供 consult 风格候选 (vertico+orderless);
;; dired-sidebar 走 projectile 检测根目录 — 三者共享同一项目概念。
;; projectile-import-known-projects 自动从 project.el 已知项目迁移。
(use-package projectile
  :ensure t
  :demand t
  :custom
  (projectile-enable-caching t)              ; 大项目文件列表缓存
  (projectile-completion-system 'default)    ; 让 consult 接管候选 UI
  (projectile-show-menu nil)                 ; 隐藏菜单栏 Projectile 菜单 (只留快捷键)
  :config
  ;; 全局 minor mode 放 :config 而非 :init — 确保 :custom 先执行
  ;; (projectile-mode 启用时会读 projectile-completion-system)
  (projectile-mode 1)
  ;; 从内置 project.el 已知项目导入 (projectile 不会自动继承)
  (when (fboundp 'projectile-import-known-projects)
    (ignore-errors (projectile-import-known-projects))))

;; ---------- 状态栏 (VSCode 底部状态条: 文件名/修改/git/位置) ----------
(use-package mood-line
  :config
  (mood-line-mode 1))

;; ---------- 行号 (相对行号, evil-mode 最佳实践: 3j = 向下 3 行) ----------
(global-display-line-numbers-mode 1)
(setq display-line-numbers-type 'relative)

;; ---------- 隐藏工具条 (更像 VSCode; 需要时 M-x tool-bar-mode 可开回) ----------
(tool-bar-mode -1)

;; ---------- LSP (lsp-mode + lsp-ui; PHP/Python/JS/Rust 自动启动) ----------
;; 2026-08-17 从 eglot 整体切换: lsp-mode + lsp-ui 提供更完整的 IDE 能力 —
;; 悬浮文档 lsp-ui-doc、行尾诊断侧栏 lsp-ui-sideline、peek 跳转 lsp-ui-peek、
;; headerline 面包屑、code lens, 且生态更活跃 (lsp-treemacs 等可选)。
;; 补全仍走 CAPF: lsp-completion-mode 会把 lsp-completion-at-point 加进
;; completion-at-point-functions 首位, corfu 前端与 cape 兜底不用动
;; (init-completion.el)。
;; ⚠️ nix-mode 继续用内置 eglot + nixd (init-nix.el 自带注册, 与 lsp-mode 共存)。
;;
;; 键位 (沿用原 eglot 的 C-c e 前缀, 肌肉记忆不变):
;;   C-c e e  启动/连接 LSP            C-c e a  code action
;;   C-c e f  光标处 code action (quickfix)  C-c e o  organize imports
;;   C-c e r  rename                     C-c e d  声明处 (interface/类型)
;;   C-c e i  implementation            C-c e t  type definition
;;   C-c e R  重启 server (改 lsp-* 选项后生效)
;;   C-c e l  开启/关闭 IO 日志         C-c e L  查看 *lsp-log* (排障)
;;   M-. / M-? 仍是 xref 全局键 (lsp-mode 自动接入 definitions/references)
(use-package lsp-mode
  :bind (("C-c e e" . lsp)
         ("C-c e a" . lsp-execute-code-action)
         ("C-c e f" . lsp-code-actions-at-point)
         ("C-c e o" . lsp-organize-imports)
         ("C-c e r" . lsp-rename)
         ("C-c e d" . lsp-find-declaration)
         ("C-c e i" . lsp-find-implementation)
         ("C-c e t" . lsp-find-type-definition)
         ("C-c e R" . lsp-workspace-restart)
         ("C-c e l" . lsp-toggle-trace-io)
         ("C-c e L" . lsp-workspace-show-log))
  :hook ((php-mode . lsp-deferred)
         (python-mode . lsp-deferred)
         (python-ts-mode . lsp-deferred)
         (js-ts-mode . lsp-deferred)
         (typescript-ts-mode . lsp-deferred)
         (tsx-ts-mode . lsp-deferred)
         ;; Rust: rust-analyzer 由项目 devShell 提供 (Nix 铁律, 不装全局),
         ;; 打开项目内 .rs 文件时 envrc 自动加载 direnv 环境, lsp 才找得到它;
         ;; 项目外打开 rust-analyzer 不存在, LSP 起不来属预期。
         (rust-mode . lsp-deferred)
         (rust-ts-mode . lsp-deferred))
  :custom
  (lsp-idle-delay 0.2)                 ; 默认 0.5s idle, 调短更跟手
  (lsp-auto-guess-root t)              ; 用 projectile/project 自动猜项目根 (省去首次打开时的 import 交互)
  (lsp-headerline-breadcrumb-enable t) ; buffer 顶部面包屑路径 (类 VSCode)
  (lsp-diagnostics-provider :flymake)  ; 诊断走 flymake (init-dev.el 的 M-g n/p 绑定)
  (lsp-enable-snippet t)               ; TS auto-import 等 snippet 补全 (yas 已装)
  ;; ⚠️ 必须 :none 不能 :capf! lsp-completion-provider 只有 :capf/:none 两个值,
  ;; :capf 是 "Use company-capf" —— lsp-completion-mode 源码 (lsp-completion.el)
  ;; 里只要 provider 不是 :none 且 company 可加载 (autoload 让 fboundp 恒真),
  ;; 就会自动启用 company-mode + company-capf → 双框同屏
  ;; (company 的 cape-keyword 框 + corfu 的 LSP 框, 就是输入 expo 时的现象)。
  ;; :none = 只把 lsp-completion-at-point 挂进 completion-at-point-functions,
  ;; 不启用任何自带 UI —— 这正是 corfu 用户的正确选择。
  (lsp-completion-provider :none)
  (lsp-completion-enable t)
  (lsp-inlay-hint-enable t)            ; 内联提示 (参数名/变量类型/返回类型)
  (lsp-format-buffer-on-save t)        ; 保存自动格式化 (lsp-mode 自带 server 能力检查)
  (lsp-log-io nil)                     ; 平时不记全文 IO; 排障时 C-c e l 临时打开
  :config
  ;; 先加载 ts-ls 客户端, 再 setq 它的 defcustom (顺序反过来会被
  ;; defcustom 的默认值覆盖):
  (require 'lsp-javascript)
  ;; ---- tsserver 调优 (等价于旧 eglot 的 initializationOptions) ----
  ;; ⚠️ 全局 typescript@7.x (tsgo native 版) 没有 tsserver.js, lsp-mode 的
  ;; ts-ls 客户端解析 :system "tsserver" 找不到会直接报 "The package
  ;; typescript is not installed" → 连接失败。已在本机 ~/.local/bin/tsserver
  ;; 建了符号链接 → ~/.local/lib/tsls-deps/... (typescript@5.9.3, 自带真实
  ;; tsserver.js; workspace 有自己的 typescript 时仍优先用它)。
  ;; fallbackPath 保留作双保险 (typescript-language-server 在 path 无效/
  ;; 缺失时用它兜底)。
  ;; 变量名对应 lsp-javascript.el 的 ts-ls 客户端:
  ;;   lsp-clients-typescript-tsserver  → 初始化选项的 :tsserver {...}
  ;;   lsp-clients-typescript-preferences → 初始化选项的 :preferences {...}
  (setq lsp-clients-typescript-tsserver
        (list :fallbackPath
              "/Users/dok4ever/.local/lib/tsls-deps/node_modules/typescript/lib/tsserver.js")
        lsp-clients-typescript-preferences
        (list :completeFunctionCalls t            ; 补全函数自动带括号 foo( )
              :includeAutomaticOptionalChainCompletions t ; 可选链 ?. 自动补全
              :includeCompletionsForModuleExports t       ; 模块导出/import 自动补全
              :includeCompletionsWithInsertText t
              :includeCompletionsWithSnippetText t
              :includeCompletionsWithClassMemberSnippets t
              :includeCompletionsWithObjectLiteralMethodSnippets t
              :allowIncompleteCompletions t
              ;; inlay hints 偏好 (配合 lsp-inlay-hint-enable)
              :includeInlayParameterNameHints "literals"
              :includeInlayParameterNameHintsWhenArgumentMatchesName t
              :includeInlayFunctionParameterTypeHints t
              :includeInlayVariableTypeHints t
              :includeInlayVariableTypeHintsWhenTypeMatchesName t
              :includeInlayFunctionLikeReturnTypeHints t
              :includeInlayPropertyDeclarationTypeHints t
              :includeInlayEnumMemberValueHints t)))

;; lsp-ui: 默认全部视觉层关闭, 屏幕只留 corfu 补全列表一个框
;; 各层用途说明 (需要时可单独打开, 但都会在屏幕上产生额外框/条):
;;   lsp-ui-doc      悬浮文档 (鼠标/光标悬停弹框)     → 关, 改用 C-c e h 按需看
;;   lsp-ui-sideline 行尾侧栏 (每次按键刷新当前行符号/诊断信息框) → 关
;;   lsp-ui-imenu    接管 imenu 为侧边树              → 关, 保留 consult-imenu
;;   lsp-ui-peek     跳转参考时的 peek 预览窗         → 开 (仅在 C-c e i / M-? 时出现)
;; ⚠️ 双框根源: 开启了 lsp-ui-doc / lsp-ui-sideline 后, 补全时它们会与
;; corfu 候选列表同时出现, 视觉上就是"两个补全框"。全部禁用后可确保唯一。
(use-package lsp-ui
  :ensure t
  :after lsp-mode
  :bind (("C-c e h" . lsp-ui-doc-glance))  ; 按需看文档 (不依赖 doc-enable)
  :hook (lsp-mode . lsp-ui-mode)
  :custom
  (lsp-ui-doc-enable nil)
  (lsp-ui-doc-show-with-mouse nil)   ; 双保险 (即便 doc 被打开也不自动弹)
  (lsp-ui-doc-show-with-cursor nil)
  (lsp-ui-sideline-enable nil)
  (lsp-ui-imenu-enable nil)
  (lsp-ui-peek-enable t)
  :config
  ;; 终端 (-nw) 没有 child frame, 更没必要开这些
  (unless (display-graphic-p)
    (setq lsp-ui-doc-enable nil
          lsp-ui-sideline-enable nil)))

;; python 用 pyright (与旧 eglot 一致; lsp-mode 内置的 pylsp 是兜底)。
;; lsp-pyright 安装后自动注册 pyright 客户端 (lsp-client-packages 含 lsp-pyright),
;; 优先级高于 pylsp, 无需额外 hook。
(use-package lsp-pyright
  :ensure t
  :after lsp-mode)

;; 旧 eglot 配置 (2026-08-17 归档, 架构等价迁移到上方 lsp-* 配置):
;; - 键位 C-c e e/a/f/o/r/d/i/t 语义不变, 映射到对应 lsp-* 命令
;; - tsserver initializationOptions → lsp-clients-typescript-tsserver / -preferences
;; - 保存格式化 → lsp-format-buffer-on-save (旧 my-eglot-format-on-save 已删)
;; - 排障 → lsp-log-io + C-c e l/L (旧 eglot-events-buffer-config 已删)
;; - nix-mode 的 eglot 注册在 init-nix.el, 不受本次切换影响
;; ========== JS/TS 开发环境 (语法高亮 + 代码补全) ==========
;; 补全前端: corfu (init-completion.el 全局启用), 不再用 company。
;; lsp-mode 的 LSP 补全自动注册到 completion-at-point-functions (首位),
;; corfu 直接消费 CAPF; cape 提供 dabbrev/file/dict 兜底 (init-completion.el)。

;; ---- 1. (旧) Company 补全框架 ---- 已禁用, 改用 corfu + eglot CAPF
;; (use-package company
;;   :ensure t
;;   :hook (after-init . global-company-mode)
;;   :config
;;   (setq company-idle-delay 0
;;         company-minimum-prefix-length 2
;;         company-show-quick-access t
;;         company-tooltip-align-annotations t
;;         company-transformers '(company-sort-by-occurrence))
;;   (setq company-active-map
;;         (let ((map (make-sparse-keymap)))
;;           (define-key map (kbd "<tab>") #'company-complete-common-or-cycle)
;;           (define-key map (kbd "<backtab>") #'company-select-previous)
;;           (define-key map (kbd "C-n") #'company-select-next)
;;           (define-key map (kbd "C-p") #'company-select-previous)
;;           (define-key map (kbd "M-n") #'company-select-next)
;;           (define-key map (kbd "M-p") #'company-select-previous)
;;           (define-key map (kbd "<return>") nil)
;;           map)))

;; ---- 2. (旧) Company Capf ---- 已禁用, corfu 直连 eglot CAPF
;; (eval-after-load 'company
;;   '(progn
;;      (add-to-list 'company-backends 'company-capf)))

;; ---- 3. JS/TS 语法增强 (js2-mode 备选; tree-sitter 优先) ----
;; tree-sitter 语法高亮 (Emacs 29+, 比 js2-mode 更精确)
(use-package treesit-auto
  :ensure t
  :config
  (setq treesit-auto-install 'prompt)
  (global-treesit-auto-mode))

;; JS/TS major-mode 配置
(add-to-list 'auto-mode-alist '("\\.js\\'" . js-ts-mode))
(add-to-list 'auto-mode-alist '("\\.mjs\\'" . js-ts-mode))
(add-to-list 'auto-mode-alist '("\\.cjs\\'" . js-ts-mode))
(add-to-list 'auto-mode-alist '("\\.jsx\\'" . js-ts-mode))
(add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode))
;; .tsx 必须用 tsx-ts-mode (treesit 的 tsx grammar):
;; 之前映射到 typescript-ts-mode 会按纯 TS 解析, JSX 标签/属性解析错位,
;; 补全和缩进都会异常。lsp-mode 的 ts-ls 客户端自带 tsx-ts-mode 映射,
;; 无需额外注册 server。
(add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))
(add-to-list 'auto-mode-alist '("\\.json\\'" . json-ts-mode))

;; JS/TS 文件处理已由上方 lsp-mode :hook 接管:
;;   js-ts-mode / typescript-ts-mode / tsx-ts-mode → lsp-deferred 自动连接
;; LSP 补全由 lsp-completion-mode 自动挂到 CAPF 首位 (lsp-completion.el 里
;;   add-to-list completion-at-point-functions #'lsp-completion-at-point),
;;   corfu 直接消费 — 旧 eglot 的 my-js-ts-eglot-capf-first 已删, 无需手动提位。
;; inlay hints 由 lsp-inlay-hint-enable 全局开启, 不再逐 buffer 手动开;
;; lsp-mode 的 lsp-inlay-hint-face 默认继承 font-lock-comment-face (淡色),
;; 旧 eglot 的 face 微调也已删。

;; ---- 4. 语法高亮增强 (高亮 TODO/FIXME/NOTE 等标记) ----
(use-package hl-todo
  :ensure t
  :config
  (global-hl-todo-mode 1)
  :custom
  (hl-todo-keyword-faces
   '(("TODO"   . "#e5c07b")   ; 黄色 - 待办
     ("FIXME"  . "#e06c75")   ; 红色 - 待修复
     ("BUG"    . "#e06c75")   ; 红色 - Bug
     ("HACK"   . "#c678dd")   ; 紫色 - 临时方案
     ("NOTE"   . "#61afef")   ; 蓝色 - 笔记
     ("XXX"    . "#56b6c2")    ; 青色 - 警告
     ("PERF"   . "#98c379")))  ; 绿色 - 性能优化
  (hl-todo-activate-in-modes '(js-ts-mode typescript-ts-mode python-ts-mode php-mode)))

;; ---------- php-mode: PHP 语法高亮 + 缩进 ----------
(use-package php-mode
  :ensure t
  :mode ("\\.php\\'" "\\.phtml\\'"))

;; ---------- 菜单栏加 "IDE" 菜单 (GUI 友好, 不用记快捷键) ----------
(easy-menu-define nil global-map "IDE"
  '("IDE"
    ["文件树 (Explorer)" dired-sidebar-toggle-sidebar t]
    ["切换到文件树窗口" dired-sidebar-jump-to-sidebar t]
    ["刷新文件树" revert-buffer t]
    ["项目内找文件" my-consult-projectile-find-file t]
    ["切换项目" projectile-switch-project t]
    ["启动 LSP" lsp t]
    ["关闭 LSP" lsp-shutdown-workspace t]
    ["运行 Rust 文件/项目 (C-c C-r)" my-rust-run t]))

;; ---------- Dashboard 极简留白: 分区标题 + 纯列表, 无框线 (CJK 对齐问题从根上消失) ----------
;; 调色: Lain 磷光绿系 (无框线版本, 颜色只做点缀)
(defconst my-dash-c-title    "#5cff87" "主标题/磷光绿 (CRT P1 荧光).")
(defconst my-dash-c-cardhead "#e6f2e8" "分区标题/窗白 (Lain UI 窗口文字).")
(defconst my-dash-c-recent   "#7be8a0" "最近文件行/浅磷光绿.")
(defconst my-dash-c-project  "#6fd0e8" "项目行/CRT 青.")
(defconst my-dash-c-agenda   "#ffc46b" "日程行/琥珀 (amber 磷光).")
(defconst my-dash-c-idle     "#4a5c4e" "占位文案/暗灰绿.")
(defconst my-dash-c-bookmark "#b79bff" "书签行/电紫.")
(defconst my-dash-c-button   "#5cff87" "导航按钮/磷光绿 (与主标题同色).")
(defconst my-dash-c-footer   "#5f9f72" "页脚/暗磷光绿.")
(defconst my-dash-card-rows 5 "Max content rows per section.")
(defconst my-dash-card-gap 4 "Horizontal gap between nav buttons, in cols.")
(defconst my-dash-matrix-gutter 6 "Horizontal gap between 2x2 matrix cells, in cols.")
(defconst my-dash-matrix-min-col 24 "Min cell width (cols) required for the 2x2 matrix layout.")

(defvar my-dash--cache nil
  "Cached dashboard data: (recents projects agenda bookmarks).")

(defun my-dash--trunc (str width)
  "Truncate STR to display WIDTH, CJK-aware."
  (let ((sw (string-width str)))
    (if (<= sw width) str
      (let ((pos 0) (w 0))
        (while (and (< w (- width 1)) (< pos (length str)))
          (setq w (+ w (char-width (aref str pos))))
          (setq pos (1+ pos)))
        (concat (substring str 0 pos) "…")))))

(defun my-dash--icon (icon)
  "Render Nerd Icon from full name like \"nf-md-folder\"."
  (unless (featurep 'nerd-icons)
    (require 'nerd-icons nil t))
  (let ((family (and (string-match "^nf-\\([a-z]+\\)-" icon)
                     (match-string 1 icon))))
    (cond
     ((string= family "fa")  (nerd-icons-faicon icon))
     ((string= family "md")  (nerd-icons-mdicon icon))
     ((string= family "oct") (nerd-icons-octicon icon))
     ((string= family "dev") (nerd-icons-devicon icon))
     ((string= family "cod") (nerd-icons-codicon icon))
     (t (nerd-icons-mdicon icon)))))

(defun my-dash--click-map (action)
  "Keymap for clickable tag.
ACTION is a Lisp form (eval'd) or a function (funcall'd)."
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET")
      (lambda (&rest _) (interactive)
        (if (functionp action) (funcall action) (eval action))))
    (define-key map [mouse-1]
      (lambda (&rest _) (interactive)
        (if (functionp action) (funcall action) (eval action))))
    (define-key map [mouse-2]
      (lambda (&rest _) (interactive)
        (if (functionp action) (funcall action) (eval action))))
    map))

;; ---------- Dashboard 数据源 (recents/projects/agenda/bookmarks) ----------
(defun my-dash--recents-data ()
  "Recent files as list of (NAME . PATH), existing files only."
  (mapcar (lambda (f)
            (cons (file-name-nondirectory (directory-file-name f)) f))
          (cl-remove-if (lambda (f)
                          (or (null f)
                              (string-match-p "^\\s-*$" f)
                              (not (file-exists-p f))))
                        (seq-take recentf-list 6))))

(defun my-dash--on-recentf-changed (&rest _)
  "Invalidate dashboard cache and re-render when recent files change.
Runs from `find-file-hook' / `kill-buffer-hook' so the Recent Files
card always reflects the latest activity."
  (when (and (boundp 'dashboard-buffer-name)
             (get-buffer dashboard-buffer-name))
    (setq my-dash--cache nil)
    (when (get-buffer-window dashboard-buffer-name)
      (with-current-buffer dashboard-buffer-name
        (dashboard-insert-startupify-lists t)))))
(add-hook 'find-file-hook #'my-dash--on-recentf-changed)
(add-hook 'kill-buffer-hook #'my-dash--on-recentf-changed)

(defun my-dash--projects-data ()
  "Projectile projects as list of (NAME . ROOT).
Filters out non-projects and bypasses projectile-project-name cache."
  (when (bound-and-true-p projectile-mode)
    (seq-mapcat
     (lambda (p)
       ;; Skip entries that aren't actual projects (e.g. no .git, no marker)
       (when (projectile-project-p p)
         (list (cons (projectile-default-project-name p) p))))
     (seq-take (projectile-relevant-known-projects) 20))))

(defun my-dash--bookmarks-data ()
  "Bookmarks as list of (NAME . LOCATION)."
  (require 'bookmark)
  (bookmark-maybe-load-default-file)
  (when (and (boundp 'bookmark-alist) bookmark-alist)
    (mapcar (lambda (bm)
              (let ((name (bookmark-name-from-full-record bm)))
                (cons name (or (bookmark-location bm) ""))))
            (seq-take bookmark-alist 5))))

;; ---------- Agenda 卡片异步加载 (2026-08-14) ----------
;; 启动阻塞根因: dashboard-insert-startupify-lists 挂在 after-init-hook,
;; 而 Agenda 卡片的 my-dash--agenda-data 会同步执行 (org-agenda nil "a"),
;; 逐个 find-file-noselect 打开全部 agenda 文件 (实测每个 ~1.9s, 6 个文件
;; 共 ~11.7s), 导致 Dashboard 十几秒后才出现。
;; (表象是 "Loading gcal-client.el...done" 之后卡住 — gcal-client.el 只是
;; 两个 setq, 毫秒级, 无辜; 卡的是它之后 after-init-hook 里的 agenda 计算。)
;; 修复: agenda 计算移到子进程 (emacs --quick + agenda-dump.el, ~1s),
;; 主 Emacs 全程可交互; 卡片先显示 "Loading calendar…" 占位, 子进程
;; 完成后 sentinel 重渲染填入。计算逻辑在 agenda-dump.el, agenda 文件
;; 列表由这里实时传入 (改 org-agenda-files 自动生效, 不复制配置)。
(defvar my-dash--agenda-rows nil
  "Agenda rows for the dashboard card, computed asynchronously once per session.")

(defvar my-dash--agenda-loading nil
  "Non-nil while the async agenda computation is pending/running.")

(defvar my-dash--agenda-watchdog nil
  "Watchdog timer: clears `my-dash--agenda-loading' if the subprocess hangs.")

(defvar my-dash--agenda-refreshed nil
  "Non-nil once the background subprocess refreshed the agenda this session.")

(defun my-dash--agenda-cache-load ()
  "Load agenda rows from the cache file (instant, previous session's data).
缓存让启动时卡片秒显, 后台子进程随后刷新 (见 `my-dash--agenda-load-async')。
缓存文件在 ~/.emacs.d/cache/ (已 gitignore)。"
  (let ((cache (expand-file-name "cache/agenda-cache.el" user-emacs-directory)))
    (when (and (not my-dash--agenda-rows) (file-exists-p cache))
      (condition-case nil
          (let ((data (with-temp-buffer
                        (insert-file-contents cache)
                        (read (current-buffer)))))
            (when (consp data)
              (setq my-dash--agenda-rows data)))
        (error nil)))))

(defun my-dash--agenda-files ()
  "Agenda file list, or nil when `org-agenda-files' is not defined yet.
org 是懒加载的 (init-org.el `:defer t'): 启动早期这个变量可能根本不存在,
所以要区分 \"org 还没加载\" 和 \"没有 agenda 文件\" 两种情况。"
  (when (boundp 'org-agenda-files)
    (let ((files org-agenda-files))
      (if (listp files) files (list files)))))

(defun my-dash--agenda-abort (why)
  "Give up this refresh round: clear loading/watchdog, keep cached rows.
WHY 会记入 *Messages*。任何错误路径都必须走这里 — 否则
`my-dash--agenda-loading' 留在 t, 卡片永远显示 \"Loading calendar…\"
(2026-09-26 的 void-variable org-agenda-files 就是这么卡住的)。"
  (setq my-dash--agenda-loading nil)
  (when my-dash--agenda-watchdog
    (cancel-timer my-dash--agenda-watchdog)
    (setq my-dash--agenda-watchdog nil))
  (message "Dashboard agenda: %s (保留缓存数据)" why)
  (my-dash--rerender))

(defun my-dash--agenda-load-async ()
  "Compute agenda data in a background --quick Emacs subprocess (~1s).
org-agenda 在 GUI 里逐个打开 agenda 文件很慢 (实测 ~2s/文件) — 同步计算
会冻结主界面。策略:
  1) 有缓存文件 → 立即显示 (昨天的数据, 无 Loading 占位)
  2) 每会话派一次子进程 (emacs --quick --batch + agenda-dump.el, ~1s)
     刷新数据, sentinel 完成后更新卡片并重写缓存
本会话已刷过 / 没有 emacs / org 还没加载 (拿不到文件清单) → 什么都不做,
保持缓存数据 (不摆 \"Loading…\" 占位); org 加载后由下面的
`with-eval-after-load' 补一次。本函数是从渲染里调用的, 所以这里不重渲染。"
  (unless my-dash--agenda-loading
    (my-dash--agenda-cache-load)
    (let ((emacs (executable-find "emacs"))
          (files (my-dash--agenda-files)))
      (when (and (not my-dash--agenda-refreshed) emacs files)
        (setq my-dash--agenda-loading t)
        (let ((script (expand-file-name "agenda-dump.el" user-emacs-directory))
              (out "/tmp/my-dash-agenda.out"))
          ;; 看门狗先挂上 (不能放在 make-process 之后: 派生失败会跳过它,
          ;; loading 就再也清不掉了): 子进程挂死 15s 后放弃并保留缓存数据。
          (setq my-dash--agenda-watchdog
                (run-at-time 15 nil
                             (lambda ()
                               (when my-dash--agenda-loading
                                 (my-dash--agenda-abort "子进程超时 (15s)")))))
          (condition-case err
              (progn
                (delete-file out t)
                (make-process
                 :name "my-dash-agenda"
                 :buffer (generate-new-buffer " *my-dash-agenda*")
                 :command
                 (list emacs "--quick" "--batch"
                       "-l" script
                       "--eval"
                       (format "(my-agenda-dump (quote (%s)) %S)"
                               (mapconcat (lambda (f) (format "%S" (expand-file-name f)))
                                          files " ")
                               out))
                 :sentinel #'my-dash--agenda-sentinel))
            (error (my-dash--agenda-abort
                    (format "派生失败: %s" (error-message-string err))))))))))

;; org 懒加载 (init-org.el :defer t): 启动时可能读不到 org-agenda-files,
;; 那一轮不派生。org 一旦加载 (打开 .org / C-c a / C-c c) 立刻补刷一次。
(with-eval-after-load 'org
  (when (and (my-dash--agenda-files) (not my-dash--agenda-refreshed))
    (my-dash--refresh-cache)
    (my-dash--rerender)))

(defun my-dash--agenda-sentinel (proc _event)
  "Subprocess finished: read the result sexp, update cache and re-render."
  (when (memq (process-status proc) '(exit signal))
    (when my-dash--agenda-watchdog
      (cancel-timer my-dash--agenda-watchdog)
      (setq my-dash--agenda-watchdog nil))
    (let ((ok (eq (process-exit-status proc) 0))
          (out "/tmp/my-dash-agenda.out"))
      (when (buffer-live-p (process-buffer proc))
        (kill-buffer (process-buffer proc)))
      (setq my-dash--agenda-loading nil)
      (setq my-dash--agenda-refreshed t)
      (let ((data (and ok
                       (file-exists-p out)
                       (condition-case nil
                           (with-temp-buffer
                             (insert-file-contents out)
                             (read (current-buffer)))
                         (error nil)))))
        (if (consp data)
            (progn
              (setq my-dash--agenda-rows data)
              ;; 写缓存: 下次启动秒显 (cache/ 已 gitignore)
              (condition-case nil
                  (with-temp-file
                      (expand-file-name "cache/agenda-cache.el" user-emacs-directory)
                    (insert (prin1-to-string data)))
                (error nil)))
          ;; 失败也保留缓存数据 (卡片不会变空), 但留条线索便于排查
          (message "Dashboard agenda: %s, 保留缓存数据"
                   (if ok "子进程无输出"
                     (format "子进程退出码 %s" (process-exit-status proc))))))
      ;; 重建 cache (agenda 槽换新数据) — 直接 rerender 会用启动时的
      ;; 旧 cache (agenda 槽 nil), 卡片停留在占位/不可用状态 (2026-08-14)。
      ;; refresh-cache 内部的 agenda-load-async 有 rows 非 nil 守卫, 不会重复派生。
      (my-dash--refresh-cache)
      ;; 无论成败都重渲染, 把 \"Loading…\" 换成数据或空状态文案
      (my-dash--rerender))))

(defun my-dash--rerender ()
  "Re-render the dashboard buffer if it exists and is visible."
  (when (and (boundp 'dashboard-buffer-name)
             (get-buffer dashboard-buffer-name)
             (get-buffer-window dashboard-buffer-name))
    (with-current-buffer (get-buffer dashboard-buffer-name)
      (dashboard-insert-startupify-lists t))))

(defun my-dash--refresh-cache ()
  "Fill `my-dash--cache' from data sources.
Agenda comes from `my-dash--agenda-rows' (缓存文件 + 后台子进程刷新,
see `my-dash--agenda-load-async'), so startup never blocks on org-agenda."
  ;; 先把缓存文件读进 `my-dash--agenda-rows': 否则首帧 cache 的 agenda 槽是
  ;; nil, 卡片要先闪一次 \"Loading…\" 才换成数据 (2026-09-26)。
  (my-dash--agenda-cache-load)
  (setq my-dash--cache
        (list (my-dash--recents-data)
              (my-dash--projects-data)
              my-dash--agenda-rows
              (my-dash--bookmarks-data)))
  (my-dash--agenda-load-async))

(defun my-dash--insert-block (lines)
  "把 LINES (字符串列表) 作为整块按最宽行居中插入 (无框线, 误差不可见)."
  (let* ((win (get-buffer-window dashboard-buffer-name 'all-frames))
         (ww (if win (window-width win) 80))
         (w (apply #'max (mapcar #'string-width lines)))
         (pad (make-string (max 0 (/ (- ww w) 2)) ?\s)))
    (dolist (l lines)
      (insert (if (equal l "") "\n" (concat pad l "\n"))))))

(defun my-dash--lines-width (lines)
  "Display width of the widest line in LINES (0 when empty)."
  (if lines (apply #'max (mapcar #'string-width lines)) 0))

(defun my-dash--pad (str width)
  "Right-pad STR with spaces to display WIDTH (never truncates)."
  (concat str (make-string (max 0 (- width (string-width str))) ?\s)))

(defun my-dash--merge-face (base extra)
  "BASE (图标原有 face, 可为 nil) 与 EXTRA (前景色 plist) 合成 face 列表."
  (if base (list base extra) extra))

(defun my-dash--navigator-btn (btn)
  "渲染单个导航按钮: icon 保留 nerd-icons 字体 face + 磷光绿前景, 可点击."
  (let* ((icon (car btn)) (title (cadr btn))
         (help (caddr btn)) (action (cadddr btn))
         (km (my-dash--click-map action))
         (fg (list :foreground my-dash-c-button))
         (iface (get-text-property 0 'face icon))
         (hov (my-dash--merge-face iface 'highlight)))
    (concat
     (propertize icon 'face (my-dash--merge-face iface fg)
                 'mouse-face hov 'keymap km 'help-echo help)
     " "
     (propertize title 'face fg 'mouse-face 'highlight
                 'keymap km 'help-echo help))))

(defun my-dash--navigator-flow ()
  "导航按钮流式分行: 行数取窗口宽下最少行, 各行像素长度均衡 (等长)."
  (let* ((win (get-buffer-window dashboard-buffer-name 'all-frames))
         (cell (if (display-graphic-p) (frame-char-width) 11))
         (avail (max 200 (if win
                             (- (window-body-width win t) (* 4 cell))
                           (* 90 cell))))
         (buttons (apply #'append dashboard-navigator-buttons))
         (strs (mapcar #'my-dash--navigator-btn buttons))
         (pxs (mapcar #'string-pixel-width strs))
         (gaps (* my-dash-card-gap cell))
         (total (+ (apply #'+ pxs) (* (1- (length pxs)) gaps)))
         ;; 行数 = 贪心装箱的最少可行行数
         (n (let ((k 1) (row (car pxs)))
              (dolist (p (cdr pxs) k)
                (let ((need (+ row gaps p)))
                  (if (> need avail)
                      (setq k (1+ k) row p)
                    (setq row need))))))
         (rows-left n)
         (rem (length pxs))
         (alloc 0)
         (tgt (if (> n 1) (/ total (float n)) total))
         rows cur-strs cur-px)
    ;; 均衡装箱: 超出窗口宽强制换行; 未超但已达均分目标且剩余按钮
    ;; 够分给剩余行时也换行 → 各行长度对齐
    (dotimes (i (length strs))
      (let* ((s (nth i strs))
             (p (nth i pxs))
             (need (+ p (if cur-strs gaps 0))))
        (when (and cur-strs
                   (> rows-left 1)
                   (or (> (+ cur-px need) avail)
                       (and (> (+ cur-px need) tgt)
                            (>= rem (1- rows-left)))))
          (setq rows (append rows (list (nreverse cur-strs)))
                alloc (+ alloc cur-px)
                rows-left (1- rows-left)
                tgt (/ (- total alloc) (float rows-left))
                cur-strs nil cur-px 0
                need p))
        (setq cur-strs (cons s cur-strs)
              cur-px (+ (or cur-px 0) need)
              rem (1- rem))))
    (when cur-strs
      (setq rows (append rows (list (nreverse cur-strs)))))
    (setq rows (nreverse rows))
    (mapcar (lambda (row)
              (mapconcat #'identity row (make-string my-dash-card-gap ?\s)))
            rows)))

(defun my-dash-insert-navigator ()
  "极简导航: 按钮流式分行, 整块居中, 无框线."
  (when dashboard-navigator-buttons
    (my-dash--insert-block (my-dash--navigator-flow))
    (insert "\n")))

(defun my-dash--section-lines (sec text-width)
  "Render SEC (ICON LABEL ROWS) as one cell: heading + TEXT-WIDTH-truncated rows."
  (let ((icon (nth 0 sec)) (label (nth 1 sec)) (rows (nth 2 sec))
        (lines nil))
    (push (concat (my-dash--icon icon) "  "
                  (propertize label 'face (list :foreground my-dash-c-cardhead
                                                :weight 'bold)))
          lines)
    (dolist (r rows)
      (let* ((fg `(:foreground ,(nth 3 r)))
             (act (nth 2 r))
             (txt (my-dash--trunc (nth 1 r) text-width)))
        (push (concat "  " (my-dash--icon (nth 0 r)) " "
                      (if act
                          (propertize txt 'face fg
                                      'keymap (my-dash--click-map act)
                                      'mouse-face 'highlight
                                      'help-echo (format "RET: %S" act))
                        (propertize txt 'face fg)))
              lines)))
    (nreverse lines)))

(defun my-dash--matrix-lines (cells)
  "Lay CELLS (four cell line lists) out as 2x2, row-major: 上排 0/1, 下排 2/3.
每格右补空格对齐到本列最宽行 (列宽取该列上下两格的较宽者), 列间留
`my-dash-matrix-gutter', 两行之间空一行."
  (let* ((cw (mapcar (lambda (i)
                       (max (my-dash--lines-width (nth i cells))
                            (my-dash--lines-width (nth (+ i 2) cells))))
                     '(0 1)))
         (gutter (make-string my-dash-matrix-gutter ?\s))
         (lines nil))
    (dotimes (r 2)
      (let* ((a (nth (* 2 r) cells))
             (b (nth (1+ (* 2 r)) cells))
             (n (max (length a) (length b))))
        (dotimes (i n)
          (push (concat (my-dash--pad (or (nth i a) "") (nth 0 cw))
                        gutter
                        (my-dash--pad (or (nth i b) "") (nth 1 cw)))
                lines)))
      (when (= r 0) (push "" lines)))
    (nreverse lines)))

(defun my-dash-insert-sections ()
  "极简留白: 四个分区 (标题 + 纯列表). 窗口够宽排 2x2 矩阵, 窄则退回单列堆叠."
  (unless my-dash--cache
    (my-dash--refresh-cache))
  (let ((recents (nth 0 my-dash--cache))
        (projects (nth 1 my-dash--cache))
        (agenda (nth 2 my-dash--cache))
        (bookmarks (nth 3 my-dash--cache)))
    (let ((sections
           (list
            (list "nf-fa-files_o" "Recent Files"
                  (mapcar (lambda (f)
                            (list "nf-md-file" (car f)
                                  (list 'find-file-existing (cdr f))
                                  my-dash-c-recent))
                          (seq-take recents my-dash-card-rows)))
            (list "nf-fa-folder_open_o" "Projects"
                  (mapcar (lambda (p)
                            (list "nf-md-folder" (car p)
                                  (list 'projectile-switch-project-by-name (cdr p))
                                  my-dash-c-project))
                          (seq-take projects my-dash-card-rows)))
            (list "nf-fa-calendar" "Agenda"
                  (if agenda
                      (mapcar (lambda (a)
                                (list "nf-md-calendar_clock" (car a)
                                      '(org-agenda nil "a") my-dash-c-agenda))
                              (seq-take agenda my-dash-card-rows))
                    (list (list "nf-md-calendar_clock"
                                (if my-dash--agenda-loading
                                    "Loading calendar…"
                                  "Agenda unavailable")
                                nil my-dash-c-idle))))
            (list "nf-fa-bookmark_o" "Bookmarks"
                  (mapcar (lambda (b)
                            (list "nf-md-bookmark" (car b)
                                  (list 'bookmark-jump (car b)) my-dash-c-bookmark))
                          (seq-take bookmarks my-dash-card-rows))))))
      (let* ((win (get-buffer-window dashboard-buffer-name 'all-frames))
             (ww (if win (window-width win) 80))
             ;; 2x2 要求两列各留够宽度, 否则退回单列 (窄窗口/分屏下更易读)
             (two-col (>= ww (+ (* 2 my-dash-matrix-min-col) my-dash-matrix-gutter)))
             (text-width (if two-col
                             ;; 每格文本上限 44 (与单列时一致), 窗窄时收窄避免撞列
                             (max 16 (min 44 (- (/ (- ww my-dash-matrix-gutter) 2) 4)))
                           44))
             (cells (mapcar (lambda (sec) (my-dash--section-lines sec text-width))
                            sections)))
        (my-dash--insert-block
         (if two-col
             (my-dash--matrix-lines cells)
           (cdr (apply #'append
                       (mapcar (lambda (c) (cons "" c)) cells)))))))))

(defvar my-dash--resize-timer nil "resize 防抖 timer.")
(defun my-dash--resize-rerender (&rest _)
  (when (and (boundp 'dashboard-buffer-name)
             (get-buffer dashboard-buffer-name)
             (get-buffer-window dashboard-buffer-name 'all-frames))
    (when my-dash--resize-timer (cancel-timer my-dash--resize-timer))
    (setq my-dash--resize-timer
          (run-with-timer 0.2 nil
                          (lambda ()
                            (when (and (get-buffer dashboard-buffer-name)
                                       (get-buffer-window dashboard-buffer-name 'all-frames))
                              (with-current-buffer dashboard-buffer-name
                                (dashboard-insert-startupify-lists t))))))))
(add-hook 'window-size-change-functions #'my-dash--resize-rerender)

;; ---------- Dashboard 导航页 (emacs-dashboard 包, 参考 condy0919) ----------
;; C-c h 随时回到 Dashboard (home)
(global-set-key (kbd "C-c h") #'dashboard-open)
(use-package nerd-icons
  :ensure t
  :when (display-graphic-p)
  :demand t)

(use-package dashboard
  :ensure t
  :init
  ;; Navigator 按钮分两行: 第一行 = 邮件 + IDE, 第二行 = 人生管理 (org)
  ;; (fboundp 守卫: nerd-icons 未加载时回退到文字图标)
  (setq dashboard-navigator-buttons
        `(((,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-mail") "✉")
            "Mail" "Gnus 收邮件"
            (lambda (&rest _) (gnus)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-pencil") "✍")
            "Gmail" "撰写 Gmail"
            (lambda (&rest _) (my-compose-gmail)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-paper_airplane") "✈")
            "126" "撰写 126 邮件"
            (lambda (&rest _) (my-compose-mail126)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-file_directory") "📂")
            "File Tree" "打开 dired-sidebar 侧边栏"
            (lambda (&rest _) (dired-sidebar-toggle-sidebar)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-sign_out") "🚪")
            "Quit" "退出 Emacs"
            (lambda (&rest _) (save-buffers-kill-terminal))))
          ;; 第二行: 人生管理 (org)
          ((,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-calendar") "📅")
            "Agenda" "人生管理主视图: 本周日程 + 待办"
            (lambda (&rest _) (org-agenda nil "n")))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-plus") "✚")
            "Capture" "快速捕获任务/笔记 (C-c c)"
            (lambda (&rest _) (org-capture)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-pencil") "✍")
            "New Note" "直接新建笔记 (跳过模板选择)"
            (lambda (&rest _) (org-capture nil "n")))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-inbox") "📥")
            "Inbox" "打开收集箱 inbox.org"
            (lambda (&rest _) (find-file "~/org/inbox.org")))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-repo") "🗂")
            "Projects" "打开项目树 projects.org"
            (lambda (&rest _) (find-file "~/org/projects.org")))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-book") "📔")
            "Journal" "打开日记 journal.org"
            (lambda (&rest _) (find-file "~/org/journal.org")))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-note") "📝")
            "Notes" "打开笔记索引 index.org"
            (lambda (&rest _) (find-file "~/org/index.org"))))))
  (dashboard-setup-startup-hook)
  :custom
  (dashboard-set-heading-icons t)
  (dashboard-set-file-icons t)
  (dashboard-center-content t)
  (dashboard-vertically-center-content t)
  (dashboard-banner-logo-title "Present day, present time.")
  ;; 四模块: recents/projects/agenda/bookmarks (极简分区渲染, 见 my-dash-insert-sections)
  (dashboard-items '((recents . 6)
                     (projects . 5)
                     (agenda . 5)
                     (bookmarks . 5)))
  (dashboard-projects-backend 'projectile)
  ;; 最近文件路径太长 → 截断开头 (只留文件名附近), 最大 40 字符
  (dashboard-path-style 'truncate-beginning)
  (dashboard-path-max-length 40)
  ;; footer 文案: Lain 语录 (英文), 每次启动随机一条, 带 Emacs 版本号
  (dashboard-footer-messages
   (list (format "No matter where you go, everyone's connected. (Emacs %s)" emacs-version)
         (format "Let's all love Lain. (Emacs %s)" emacs-version)
         (format "I'm only happy when I'm in the Wired. (Emacs %s)" emacs-version)))
  (dashboard-startupify-list
   '(dashboard-insert-banner-title
     dashboard-insert-newline
     my-dash-insert-navigator
     dashboard-insert-newline
     dashboard-insert-init-info
     dashboard-insert-newline
     my-dash-insert-sections
     dashboard-insert-newline
     dashboard-insert-footer))
  :custom-face
  ;; 标题/footer 用 DotGothic16 点阵 (含完整 ASCII 字形, 英文直接走点阵;
  ;; 全局 fontset 只把 CJK 映射到 PingFang, 不映射拉丁字母, 故无需 fontset 兜底)。
  (dashboard-banner-logo-title ((t (:height 2.0 :weight bold :foreground "#5cff87" :family "DotGothic16"))))
  (dashboard-footer-face ((t (:foreground "#5f9f72" :slant italic :family "DotGothic16")))))

;; 启动信息行英文化 (默认 "Emacs started in X seconds")
(setq dashboard-init-info
      (lambda ()
        (format "Startup: %.2f s"
                (float-time (time-subtract after-init-time before-init-time)))))

;; 最近文件记录 (dashboard recents 依赖)
(recentf-mode 1)

;; tab-bar-tab-name-format: 用默认 (tab-bar-buffers 自带文件名显示)
;; 不再自定义 🏠 Home — 那段返回纯字符串无 text properties,
;; 导致 tab-bar-buffers 渲染整个 tab 列表为空 (tab 不显示)。

(provide 'ide)
;;; ide.el ends here
