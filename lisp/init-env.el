;;; init-env.el --- 环境集成 (PATH / direnv / snippets / treesit) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; exec-path-from-shell: 从 shell 继承 PATH (nix/homebrew 的命令在 GUI Emacs 里才能找到)
;; envrc: direnv 集成 (进入 .envrc 项目目录自动设置环境变量)
;; yasnippet: 代码片段模板展开
;; treesit-auto: 自动安装 tree-sitter 语法, 代码高亮/缩进更精准

;;; Code:

;; ---------- exec-path-from-shell: 继承 shell PATH ----------
;; GUI Emacs 不继承 shell 的 PATH (nix/homebrew 的命令找不到)
;; 用此包把 shell PATH 同步到 exec-path 和 PATH 环境变量
(use-package exec-path-from-shell
  :ensure t
  :when (memq window-system '(mac ns pgtk))
  :init
  (exec-path-from-shell-initialize)
  :custom
  (exec-path-from-shell-arguments '("-l"))) ; login shell

;; ---------- envrc: direnv 集成 ----------
;; 项目根目录有 .envrc 文件时, 自动 direnv allow 并加载环境变量
(use-package envrc
  :ensure t
  :init
  (envrc-global-mode 1))

;; ---------- yasnippet: 代码片段 ----------
;; 输入关键词 + Tab 展开 (如 "main" → main 函数模板)
(use-package yasnippet
  :ensure t
  :init
  (yas-global-mode 1)
  :custom
  (yas-triggers-in-field t)                ; 嵌套 snippet 允许
  :config
  ;; yasnippet-snippets: 社区通用 snippet 库
  (use-package yasnippet-snippets
    :ensure t
    :after yasnippet
    :demand t))

;; ---------- treesit-auto: tree-sitter 自动安装 ----------
;; Emacs 29+ 内置 tree-sitter, 但语法包需手动装
;; treesit-auto 按文件类型自动安装对应语法, 高亮/缩进更精准
(use-package treesit-auto
  :ensure t
  :init
  (global-treesit-auto-mode 1)
  :custom
  (treesit-auto-install 'prompt)           ; 首次使用时提示安装
  :config
  (treesit-auto-add-to-auto-mode))

(provide 'init-env)
;;; init-env.el ends here
