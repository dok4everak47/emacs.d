;;; init-evil.el --- Vim 仿真 (evil-mode) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; evil: Emacs 最好的 Vim 仿真层, 提供 Normal/Insert/Visual/Operator-pending 模式
;; evil-collection: 为各种 major-mode 提供统一的 evil 快捷键
;; evil-surround: 环绕操作 (cs"' 改引号, ds" 删引号, yss" 加引号)
;; evil-nerd-commenter: gcc 注释切换
;;
;; 退出 insert 模式: C-g 或 Esc (无延迟)

;;; Code:

;; ---------- evil: Vim 仿真核心 ----------
(use-package evil
  :ensure t
  :init
  (setq evil-want-keybinding nil       ; 由 evil-collection 统一管 keybinding
        evil-want-C-u-delete t         ; C-u 在 insert 模式删到行首 (Vim 习惯)
        evil-want-C-u-scroll t         ; C-u/C-d 上下半屏滚动
        evil-want-Y-yank-to-eol t      ; Y 复制到行尾 (和 D/C 一致)
        evil-respect-visual-char-mode t ; char 模式下不跨行
        evil-esc-delay 0              ; Esc 无延迟 (不和 meta 冲突)
        evil-cross-lines t)            ; 移动可跨行
  :config
  (evil-mode 1)
  ;; C-g 退出 insert/emacs 模式 (比 Esc 快)
  (define-key evil-insert-state-map (kbd "C-g") 'evil-normal-state)
  (define-key evil-insert-state-map (kbd "C-e") 'end-of-line)
  (define-key evil-insert-state-map (kbd "C-a") 'beginning-of-line)
  ;; C-h 在 insert 模式退格 (而非 prefix), 和 Vim 一致
  (define-key evil-insert-state-map (kbd "C-h") 'evil-delete-backward-char-and-join))

;; ---------- evil-collection: 统一 major-mode 快捷键 ----------
;; 为 magit, dired, ibuffer, ediff, ert 等数十个 mode 提供 evil 快捷键
(use-package evil-collection
  :ensure t
  :after evil
  :config
  (evil-collection-init))

;; ---------- evil-surround: 环绕操作 ----------
;; cs"' — 把双引号改单引号
;; ds" — 删掉双引号
;; yss" — 给整行加双引号
;; visual 模式下 S" — 给选区加引号
(use-package evil-surround
  :ensure t
  :after evil
  :config
  (global-evil-surround-mode 1))

;; ---------- evil-nerd-commenter: 注释切换 ----------
;; gc 作为 evil operator, 自然支持 gcc/gc3j/gcG/gc + motion
(use-package evil-nerd-commenter
  :ensure t
  :after evil
  :config
  (define-key evil-normal-state-map "gc" 'evilnc-comment-operator)
  (define-key evil-visual-state-map "gc" 'evilnc-comment-operator))

(provide 'init-evil)
;;; init-evil.el ends here
