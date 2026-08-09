;;; init-nix.el --- Nix 语言支持: 高亮 + 补全 + LSP + 保存格式化 -*- lexical-binding: t -*-

;;; Commentary:
;;
;; 放弃 nix-ts-mode (treesit 缩进对空行/let-in 不稳), 改用 nix-mode (SMIE 缩进,
;; 纯 elisp 不依赖 grammar)。nixd LSP 与 major mode 解耦, 补全/格式化不受影响。
;;
;; 四件套:
;;   - nix-mode (MELPA): 语法高亮 + SMIE 缩进 (2 空格, 经典括号深度算法)
;;   - nixd (nixpkgs, nix profile install): Nix LSP server, eglot 提供
;;     补全/悬停/跳转; 补全弹窗走 corfu (init-completion.el)
;;   - nixfmt (nixpkgs): 保存时格式化 (C-x C-s → eglot-format-buffer → nixd → nixfmt)
;;   - tree-sitter-nix grammar: 已按 treesit-auto-langs 排除 nix (见 init-env.el)

;;; Code:

(use-package nix-mode
  :ensure t
  :mode ("\\.nix\\'" . nix-mode)
  :hook ((nix-mode . eglot-ensure)
         (nix-mode . (lambda () (setq-local smie-indent-basic 2)))) ; 2 空格缩进 (buffer-local, 不影响其他 SMIE mode)
  :custom
  (nix-mode-use-smie t)                       ; SMIE 缩进 (默认即 t, 显式锁死)
  :config
  ;; 保存时格式化 (走 eglot → nixd → nixfmt)
  ;; ⚠️ eglot-format-buffer 在 LSP 未连时抛 jsonrpc-error → 阻断保存!
  ;; 守卫: 只在 eglot--managed-mode 已激活时才格式化, 否则跳过 (正常保存)。
  (defun my-nix-format-on-save ()
    "保存时格式化 nix buffer, 仅当 eglot 已连上 nixd。"
    (when (bound-and-true-p eglot--managed-mode)
      (condition-case nil
          (eglot-format-buffer)
        (error nil))))
  (add-hook 'nix-mode-hook
            (lambda () (add-hook 'before-save-hook #'my-nix-format-on-save nil t)))
  ;; eglot server 注册 + nixd 初始化选项
  ;; nixd 补全需要 initializationOptions 告诉它 nixpkgs 在哪 (默认空 → 无补全)。
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 (cons 'nix-mode
                       '("nixd"
                         :initializationOptions
                         (:nixpkgs (:expr "import <nixpkgs> {}")
                          :formatting (:provider "nixfmt")))))))

(provide 'init-nix)
;;; init-nix.el ends here