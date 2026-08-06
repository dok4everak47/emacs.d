;;; init-term.el --- 内嵌终端 (vterm) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; vterm: Emacs 中最快的终端模拟器 (C 实现, libvterm)
;; 依赖: cmake (编译期) — brew install cmake
;; 快捷键: C-c t 打开终端, C-c T 在项目根目录打开终端

;;; Code:

;; ---------- vterm: 内嵌终端 ----------
;; vterm 是 C 模块, 首次安装时需 cmake 编译 libvterm
;; 如果 cmake 未安装, :ensure 会失败 — 请先 brew install cmake
(use-package vterm
  :ensure t
  :commands (vterm vterm-other-window)
  :bind
  (("C-c v" . vterm)                        ; 当前窗口打开终端
   ("C-c V" . vterm-other-window))          ; 新窗口打开终端
  :custom
  (vterm-maximum-scrollback 10000)          ; 回滚行数
  (vterm-shell (or (executable-find "bash")
                   "/bin/bash"))            ; 用 bash (nix 5.3 优先)
  (vterm-term-environment-variable "TERM=xterm-256color")
  (vterm-kill-buffer-on-exit t)            ; 退出终端自动关 buffer
  :config
  ;; 退出 vterm buffer 时不杀整个窗口 (避免误关编辑器窗口)
  (setq vterm-buffer-name "vterm"
        vterm-buffer-name-string "vterm")
  ;; Emacs 的 copy-mode 快速滚动 (C-c C-y 进入/退出)
  (define-key vterm-mode-map (kbd "C-c C-y") #'vterm-copy-mode))

(provide 'init-term)
;;; init-term.el ends here
