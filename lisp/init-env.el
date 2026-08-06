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
;;
;; 性能优化: exec-path-from-shell-initialize 每次启动都跑一个 login shell
;; 抓 PATH (实测 0.89s)。首次抓取后把结果缓存到 cache/exec-path.el,
;; 之后启动直接读缓存 (~0.01s)。nix 环境变了想刷新: M-x my-refresh-exec-path。
(use-package exec-path-from-shell
  :ensure t
  :when (memq window-system '(mac ns pgtk))
  :custom
  (exec-path-from-shell-arguments '("-l"))   ; login shell
  :config
  (defvar my-exec-path-cache-file
    (expand-file-name "cache/exec-path.el" user-emacs-directory))

  (defun my-refresh-exec-path ()
    "重新从 shell 抓取 PATH 并更新缓存 (nix 环境变了时用)."
    (interactive)
    (exec-path-from-shell-initialize)
    (make-directory (file-name-directory my-exec-path-cache-file) t)
    (with-temp-file my-exec-path-cache-file
      (insert (format "(setq exec-path %S)\n(setenv \"PATH\" %S)\n"
                      exec-path (getenv "PATH"))))
    (message "exec-path refreshed"))

  (if (file-exists-p my-exec-path-cache-file)
      (load my-exec-path-cache-file)         ; 缓存命中: 直接读, 不跑 shell
    (my-refresh-exec-path)))

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
;;
;; 性能优化: global-treesit-auto-mode 启动激活会扫描全部已装语法 (0.45s),
;; 延迟到首次打开文件时再激活, 启动时间省 0.45s。
(use-package treesit-auto
  :ensure t
  :custom
  (treesit-auto-install 'prompt)           ; 首次使用时提示安装
  :config
  (defvar my-treesit-auto-activated nil)
  (defun my-treesit-auto-activate ()
    "首次打开文件时激活 treesit-auto (懒加载, 加速启动)."
    (unless my-treesit-auto-activated
      (setq my-treesit-auto-activated t)
      (global-treesit-auto-mode 1)
      (treesit-auto-add-to-auto-mode-alist)))
  (add-hook 'after-find-file-hook #'my-treesit-auto-activate))

(provide 'init-env)
;;; init-env.el ends here
