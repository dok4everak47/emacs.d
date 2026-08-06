;;; ide.el — VSCode 风格 IDE 外观层
;;;
;;; 独立于邮件配置 (init.el)。不想要时: 删掉本文件 + init.el 末尾两行即可还原。
;;; 依赖: 网络可访问清华 ELPA 镜像 (首次加载自动安装缺失包)。
;;; 注意: 本文件不启用 native-comp (见 early-init.el), 包走字节码, 功能不受影响。

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
  (load-theme 'doom-one t))

;; ---------- 字体 (macOS 自带 SF Mono) ----------
(set-face-attribute 'default nil :family "SF Mono" :height 140)

;; ---------- 标签页 (VSCode 上方 tab, 可鼠标点击/关闭) ----------
(tab-bar-mode 1)

;; ---------- 侧边栏文件树 (VSCode 左侧 Explorer) ----------
(use-package treemacs
  :config
  (setq treemacs-width 28
        treemacs-position 'left
        treemacs-follow-mode t          ; 光标切 buffer 时文件树自动跟随
        treemacs-file-event-mode t      ; 外部文件变更自动刷新
        treemacs-project-follow-mode t)
  (global-set-key (kbd "C-c t t") #'treemacs)          ; 打开/关闭文件树
  (global-set-key (kbd "C-c t d") #'treemacs-select-window))

;; ---------- 状态栏 (VSCode 底部状态条: 文件名/修改/git/位置) ----------
(use-package mood-line
  :config
  (mood-line-mode 1))

;; ---------- 行号 ----------
(global-display-line-numbers-mode 1)

;; ---------- 隐藏工具条 (更像 VSCode; 需要时 M-x tool-bar-mode 可开回) ----------
(tool-bar-mode -1)

;; ---------- LSP (内置 eglot; 手动启动, 避免没有 language server 时报错) ----------
(use-package eglot
  :bind (("C-c e e" . eglot))
  :config
  (setq eglot-autoshutdown t
        eglot-confirm-server-initiated-edits nil))

;; ---------- 菜单栏加 "IDE" 菜单 (GUI 友好, 不用记快捷键) ----------
(easy-menu-define nil global-map "IDE"
  '("IDE"
    ["文件树 (Explorer)" treemacs t]
    ["切换到文件树窗口" treemacs-select-window t]
    ["刷新文件树" treemacs-refresh t]
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
  ;; Navigator 按钮: 收邮件 / 写邮件 / 文件树 / 退出
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
            "文件树" "打开 Treemacs"
            (lambda (&rest _) (treemacs)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-sign_out") "🚪")
            "退出" "退出 Emacs"
            (lambda (&rest _) (save-buffers-kill-terminal))))))
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
