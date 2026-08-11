;;; init-term.el --- 内嵌终端 (vterm) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; vterm: Emacs 中最快的终端模拟器 (C 实现, libvterm)
;; 依赖: cmake (编译期) — brew install cmake
;; 快捷键: C-c v 打开终端, C-c V 新窗口打开终端

;;; Code:

;; ---------- vterm: 内嵌终端 ----------
;; vterm 是 C 模块, 首次安装时需 cmake 编译 libvterm
;; 快捷键: C-c v 新窗口打开终端(复用), C-c V 新窗口+强制新建终端
;; ⚠️ vterm-other-window 是"新窗口显示同一终端"(复用 buffer);
;; my-vterm-new-window 是"新窗口 + 强制新建" (可开多个).
(use-package vterm
  :ensure t
  :commands (vterm vterm-other-window)
  :bind
  (("C-c v" . vterm-other-window)            ; 新窗口打开/切到终端 (复用)
   ("C-c V" . my-vterm-new-window))         ; 新窗口 + 强制新建终端
  :custom
  (vterm-max-scrollback 10000)             ; 回滚行数 (变量名 vterm-max-scrollback, 无 maximum)
  (vterm-shell (or (executable-find "zsh")
                   "/bin/zsh"))             ; 用 zsh (跟系统一致, nix zsh 优先)
  ;; ⚠️ 必须是裸值！vterm.el 内部会自己拼 "TERM=" 前缀；
  ;; 写 "TERM=xterm-256color" 会变成 TERM=TERM=xterm-256color，
  ;; zsh 启动时找不到 terminfo → "can't find terminal definition" 报错
  (vterm-term-environment-variable "xterm-256color")
  (vterm-kill-buffer-on-exit t)            ; 退出终端自动关 buffer
  :config
  ;; ⚠️ vterm-other-window 只是"换窗口显示同一终端" (vterm--internal 无 arg 复用 buffer)。
  ;; 定义强制新建: 新窗口 + generate-new-buffer 新终端, 可开任意多个。
  (defun my-vterm-new-window ()
    "新窗口 + 强制新建一个 vterm 终端 (可开多个)."
    (interactive)
    (vterm--internal #'pop-to-buffer t))
  ;; 退出 vterm buffer 时不杀整个窗口 (避免误关编辑器窗口)
  (setq vterm-buffer-name "vterm"
        vterm-buffer-name-string "vterm")
  ;; Emacs 的 copy-mode 快速滚动 (C-c C-y 进入/退出)
  (define-key vterm-mode-map (kbd "C-c C-y") #'vterm-copy-mode)
  ;; C-l 清屏: vterm 默认把 C-l 列入 keymap-exceptions 不传给终端,
  ;; 导致 C-l 走 Emacs 全局 recenter-top-bottom (只重居中不清屏)。
  ;; 这里显式绑回, 发 C-l 给终端进程, bash readline 的 clear-screen 生效。
  (define-key vterm-mode-map (kbd "C-l")
    (lambda () (interactive) (vterm-send-key "l" nil nil t))))

(provide 'init-term)
;;; init-term.el ends here
