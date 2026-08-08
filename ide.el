;;; ide.el — VSCode 风格 IDE 外观层 -*- lexical-binding: t -*-
;;;
;;; 独立于邮件配置 (init.el)。不想要时: 删掉本文件 + init.el 末尾两行即可还原。
;;; 依赖: 网络可访问清华 ELPA 镜像 (首次加载自动安装缺失包)。
;;; 注意: 本文件不启用 native-comp (见 early-init.el), 包走字节码, 功能不受影响。

;; 编译期声明 (包/内置模块加载后变量才有定义)
(defvar display-line-numbers-type nil)
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
(package-initialize)
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

;; ---------- 字体 (macOS 自带 SF Mono) ----------
(set-face-attribute 'default nil :family "Comic Sans MS" :height 180)

;; 中文字体: 西文字体 (Comic Sans MS) 没有中文字形, Emacs 会自动 fallback
;; 到系统默认中文字体, 导致中英文风格不统一。
;; 指定 fontset: 汉字/日文假名/谚文等 CJK 字符用苹方 (PingFang SC, macOS 内置)。
;; 想换其他中文字体, 改 "PingFang SC" 即可 (如 "Songti SC" 宋体 / "Heiti SC" 黑体)。
(dolist (charset '(kana han cjk-misc bopomofo))
  (set-fontset-font t charset (font-spec :family "PingFang SC")))

;; ---------- 标签页 (VSCode 上方 tab, 可鼠标点击/关闭) ----------
(tab-bar-mode 1)

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
  (dired-sidebar-project-root-fn #'dired-sidebar-project-root-projectile)) ; 走 projectile

;; ---------- dired 增强 (C-x d, VSCode 风格默认进项目根) ----------
;; Emacs 内置 C-x d 的 prompt 默认填 default-directory — 在非项目 buffer
;; (scratch/dashboard) 里默认指向 ~ 等非项目目录, 回车进 dired 后
;; projectile 不认, C-c p f 找不到文件。File 菜单 Open Directory 之所以
;; "能用", 是因点击菜单的当前 buffer 多在项目内 (default-directory 已是根)。
;; 修法: C-x d 包装 — 默认目录优先填 projectile-project-root, 无项目时退回
;; 原生行为 (default-directory), 保证菜单和 C-x d 行为一致。
(defun my-dired ()
  "智能 dired: prompt 默认填 projectile 项目根 (无项目时退回默认目录)."
  (interactive)
  (let ((default-directory
          (or (when (fboundp 'projectile-project-root)
                (projectile-project-root))
              default-directory)))
    (call-interactively #'dired)))
(global-set-key (kbd "C-x d") #'my-dired)

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
  :init
  (projectile-mode 1)                        ; 全局 minor mode (项目检测)
  :custom
  (projectile-enable-caching t)              ; 大项目文件列表缓存
  (projectile-completion-system 'default)    ; 让 consult 接管候选 UI
  :config
  ;; 从内置 project.el 已知项目导入 (projectile 不会自动继承)
  (when (fboundp 'projectile-import-known-projects)
    (ignore-errors (projectile-import-known-projects))))

;; ---------- consult-projectile (consult + projectile 集成) ----------
;; 用 consult 风格 (vertico 候选 + orderless 模糊) 选项目/文件/buffer。
;; 命令: C-c p p=切项目, C-c p f=项目内找文件, C-c p r=recentf,
;; C-c p b=切项目 buffer — 见 init-completion.el 的 :bind 补充。
(use-package consult-projectile
  :ensure t
  :after (consult projectile)
  :demand t
  :custom
  ;; 切项目后默认动作 (consult-projectile-switch-project 用):
  ;; 'projectile-find-file (打开项目并立刻找文件) — VSCode 切项目即看文件
  (consult-projectile-use-projectile-switch-project t))

;; ---------- 状态栏 (VSCode 底部状态条: 文件名/修改/git/位置) ----------
(use-package mood-line
  :config
  (mood-line-mode 1))

;; ---------- 行号 (相对行号, evil-mode 最佳实践: 3j = 向下 3 行) ----------
(global-display-line-numbers-mode 1)
(setq display-line-numbers-type 'relative)

;; ---------- 隐藏工具条 (更像 VSCode; 需要时 M-x tool-bar-mode 可开回) ----------
(tool-bar-mode -1)

;; ---------- LSP (内置 eglot; PHP/Python/JS 自动启动, 其他语言手动) ----------
;; PHP: php-mode + phpactor (nix devShell)
;; Python: python-ts-mode + pyright; JS/TS: js-ts-mode + typescript-language-server
;; 说明: php-ts-mode (tree-sitter 版) 在 Emacs 30.2 要求 6 个 grammar
;; (php/phpdoc/html/js/jsdoc/css), 新版 tree-sitter-php 已合并 phpdoc/jsdoc,
;; 导致缺 grammar 拒绝启动, 故退回成熟的 php-mode。
;; js-ts-mode/python-ts-mode 是软检查 (when treesit-ready-p), 无此问题。
;; 其他语言 (eglot-ensure 找不到 server 会报错) 仍用 C-c e e 手动启动
(use-package eglot
  :bind (("C-c e e" . eglot))
  :config
  (setq eglot-autoshutdown t
        eglot-confirm-server-edits nil)
  ;; LSP server 注册 (eglot 默认不知道这些 server)
  (with-eval-after-load 'eglot
    (dolist (entry '((php-mode . ("phpactor" "language-server"))
                     (python-ts-mode . ("pyright" "language-server"))
                     (python-mode . ("pyright" "language-server"))
                     (js-ts-mode . ("typescript-language-server" "--stdio"))
                     (typescript-ts-mode . ("typescript-language-server" "--stdio"))))
      (add-to-list 'eglot-server-programs entry)))
  ;; 自动启动 eglot (LSP 只在 nix devShell 里, 找不到时 eglot-ensure 会提示)
  (add-hook 'php-mode-hook #'eglot-ensure)
  (add-hook 'python-ts-mode-hook #'eglot-ensure)
  (add-hook 'js-ts-mode-hook #'eglot-ensure)
  (add-hook 'typescript-ts-mode-hook #'eglot-ensure))

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
    ["切换项目" my-consult-projectile-switch-project t]
    ["启动 LSP" eglot t]
    ["关闭 LSP" eglot-shutdown t]))

;; ---------- Dashboard 导航页 (emacs-dashboard 包, 参考 condy0919) ----------
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
            "收邮件" "Gnus 收邮件"
            (lambda (&rest _) (gnus)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-pencil") "✍")
            "Gmail" "撰写 Gmail"
            (lambda (&rest _) (my-compose-gmail)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-pencil") "✍")
            "126" "撰写 126 邮件"
            (lambda (&rest _) (my-compose-mail126)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-file_directory") "📂")
            "文件树" "打开 dired-sidebar 侧边栏"
            (lambda (&rest _) (dired-sidebar-toggle-sidebar)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-sign_out") "🚪")
            "退出" "退出 Emacs"
            (lambda (&rest _) (save-buffers-kill-terminal))))
          ;; 第二行: 人生管理 (org)
          ((,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-calendar") "📅")
            "日程" "人生管理主视图: 本周日程 + 待办"
            (lambda (&rest _) (org-agenda nil "n")))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-plus") "✚")
            "捕获" "快速捕获任务/笔记 (C-c c)"
            (lambda (&rest _) (org-capture)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-inbox") "📥")
            "收件箱" "打开收集箱 inbox.org"
            (lambda (&rest _) (find-file "~/org/inbox.org")))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-repo") "🗂")
            "项目" "打开项目树 projects.org"
            (lambda (&rest _) (find-file "~/org/projects.org")))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-book") "📔")
            "日记" "打开日记 journal.org"
            (lambda (&rest _) (find-file "~/org/journal.org"))))))
  (dashboard-setup-startup-hook)
  :custom
  (dashboard-startup-banner 'logo)
  (dashboard-set-heading-icons t)
  (dashboard-set-file-icons t)
  (dashboard-center-content t)
  (dashboard-vertically-center-content t)
  (dashboard-banner-logo-title "Welcome to Emacs")
  (dashboard-items '((recents . 10)
                     (projects . 5)))
  (dashboard-projects-backend 'project-el)
  (dashboard-startupify-list
   '(dashboard-insert-banner
     dashboard-insert-newline
     dashboard-insert-banner-title
     dashboard-insert-newline
     dashboard-insert-navigator
     dashboard-insert-newline
     dashboard-insert-init-info
     dashboard-insert-newline
     dashboard-insert-items
     dashboard-insert-newline
     dashboard-insert-footer)))

;; 最近文件记录 (dashboard recents 依赖)
(recentf-mode 1)

;; 顶部标签页: Dashboard 的 tab 显示 🏠 Home, 其他 buffer 显示原名
(setq tab-bar-tab-name-format-function
      (lambda (tab _i)
        (let ((name (alist-get 'name tab)))
          (if (string= name dashboard-buffer-name)
              "🏠 Home"
            name))))

(provide 'ide)
;;; ide.el ends here
