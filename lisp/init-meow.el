;;; init-meow.el --- 模态编辑 (meow, 替代 evil) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; meow: 轻量模态编辑 (Kakoune 式: 先选中再执行), 替代 evil-mode (2026-08 迁移)
;; 设计哲学: 不接管 major-mode 键位 — 未被 meow 占用的键穿透到原生 keymap,
;; 因此组合键 (M-*/C-S-*/Tab 等) 直接绑 org-mode-map 即可生效, 无需 state 包装。
;;
;; 快速上手:
;;   M-x meow-tutor   15 分钟交互教程
;;   SPC ?            键位表 (cheatsheet)
;;   SPC /            查看按键对应的命令 (keypad describe)
;;
;; dired 文件管理 (2026-08 实测审计):
;;   dired 初始进 motion 态, 字母键全穿透 → 原生键位基本全保留。
;;   仅 3 键被 meow 接管: j/k (行为等同 dired 上下行, 无损失)、SPC (keypad,
;;   挤掉 dired 原生"下一行" → 翻页用 C-v/M-v)。
;;   打开: C-x d / RET 进入 / ^ 上级 / g 刷新 / v 查看 / o 另开窗口
;;   批量: m 标记 u 取消 U 全消 → d 标删 x 执行 / D 直删 R 改名 C 复制
;;         M chmod G chgrp O chown S 符号链接 Z 压缩 T 时间戳 !=shell =
;;   新建: + 新目录
;;   wdired: C-x C-q 直接编辑文件名, C-c C-c 保存 (内置)
;;   dotfiles: C-x M-o 切换显示/隐藏 (dired-omit-mode)
;;   目录树: i 展开/折叠子树, TAB 子目录循环 (dired-subtree, 见 init-tools.el)
;;   自动刷新: 外部改目录后重进自动更新, 不用手动 g (dired-auto-revert-buffer)
;;
;; 布局: QWERTY (官方示例)。核心差异 vs Vim/evil:
;;   - 先选中再操作: w 标记当前词 → e 逐词扩展 → s 删除 (不是 dw!)
;;   - 删除分工: d = 删光标处 1 字符 (Vim 的 x), s = 删选区 (Vim 的 d)
;;   - 数字后置:     选中后按 2/3/4 扩展选区 (不是 2w)
;;   - SPC = keypad: SPC x f = C-x C-f, SPC m l = M-l (org 表格右移)
;;
;; 自定义 state:
;;   emacs       — 无 meow 绑定, 纯原生键 (gnus 等特殊 mode)
;;   org-agenda  — agenda 专用态 (保留原 evil-org agenda 键位, SPC/j/k 特殊处理)
;;
;; 替代原 evil 生态:
;;   evil-collection      → 不需要 (meow 不占原生键, 各 mode 原生键位直接可用)
;;   evil-surround        → surround 包 (MELPA), leader: SPC s s/d/c
;;   evil-nerd-commenter  → Emacs 原生 M-; (comment-dwim, meow 穿透)
;;   evil-org (自维护)    → init-org.el 同文件迁移 (命令保留, 绑定改用 meow)

;;; Code:

;; 前置加载: 消除编译期 "might not be defined" 警告 (运行时 use-package 会再次处理, 幂等)
(require 'meow nil t)
(require 'org-agenda nil t)
(require 'surround nil t)
;; 编译期声明 (变量在 meow-var.el 加载后才有定义, 此处 defvar 不覆盖运行时值)
(defvar meow-keypad-self-insert-undefined nil)

(use-package meow
  :ensure t
  :config
  (meow-global-mode 1))

;; ---------- meow 全局设置 ----------
(setq meow-use-cursor-position-hack t)   ; a (append) 在行尾正确追加
(setq meow-keypad-self-insert-undefined nil) ; keypad 未定义键不自动输入, 安静退出

;; ---------- QWERTY 布局 (官方示例, 见 meow repo KEYBINDING_QWERTY.org) ----------
(defun my-meow-setup ()
  (meow-motion-define-key
   '("j" . meow-next)
   '("k" . meow-prev)
   '("<escape>" . ignore))
  (meow-leader-define-key
   ;; SPC 数字 = 数字参数
   '("1" . meow-digit-argument)
   '("2" . meow-digit-argument)
   '("3" . meow-digit-argument)
   '("4" . meow-digit-argument)
   '("5" . meow-digit-argument)
   '("6" . meow-digit-argument)
   '("7" . meow-digit-argument)
   '("8" . meow-digit-argument)
   '("9" . meow-digit-argument)
   '("0" . meow-digit-argument)
   '("/" . meow-keypad-describe-key)
   '("?" . meow-cheatsheet))
  (meow-normal-define-key
   '("0" . meow-expand-0)
   '("9" . meow-expand-9)
   '("8" . meow-expand-8)
   '("7" . meow-expand-7)
   '("6" . meow-expand-6)
   '("5" . meow-expand-5)
   '("4" . meow-expand-4)
   '("3" . meow-expand-3)
   '("2" . meow-expand-2)
   '("1" . meow-expand-1)
   '("-" . negative-argument)
   '(";" . meow-reverse)
   '("," . meow-inner-of-thing)
   '("." . meow-bounds-of-thing)
   '("[" . meow-beginning-of-thing)
   '("]" . meow-end-of-thing)
   '("a" . meow-append)
   '("A" . meow-open-below)
   '("b" . meow-back-word)
   '("B" . meow-back-symbol)
   '("c" . meow-change)
   ;; d = 删光标处 1 字符 (Vim 的 x); 删选区用 s (meow-kill)!
   '("d" . meow-delete)
   '("D" . meow-backward-delete)
   '("e" . meow-next-word)
   '("E" . meow-next-symbol)
   '("f" . meow-find)
   '("g" . meow-cancel-selection)
   '("G" . meow-grab)
   '("h" . meow-left)
   '("H" . meow-left-expand)
   '("i" . meow-insert)
   '("I" . meow-open-above)
   '("j" . meow-next)
   '("J" . meow-next-expand)
   '("k" . meow-prev)
   '("K" . meow-prev-expand)
   '("l" . meow-right)
   '("L" . meow-right-expand)
   ;; m 原绑 meow-join (合并行去换行), 用户不需要, 显式禁用 (2026-08)
   '("m" . ignore)
   '("n" . meow-search)
   '("o" . meow-block)
   '("O" . meow-to-block)
   '("p" . meow-yank)
   '("q" . meow-quit)
   '("Q" . meow-goto-line)
   '("r" . meow-replace)
   '("R" . meow-swap-grab)
   '("s" . meow-kill)
   '("t" . meow-till)
   '("u" . meow-undo)
   '("U" . meow-undo-in-selection)
   '("v" . meow-visit)
   '("w" . meow-mark-word)
   '("W" . meow-mark-symbol)
   '("x" . meow-line)
   '("X" . meow-goto-line)
   '("y" . meow-save)
   '("Y" . meow-sync-grab)
   '("z" . meow-pop-selection)
   '("'" . repeat)
   '("<escape>" . ignore)))
(my-meow-setup)

;; ---------- 自定义 state: emacs (纯原生, gnus 等特殊 mode) ----------
;; 参考 doom-meow 模块: 无 meow 绑定, 只保留切回 + M-SPC keypad
(defvar my-meow-emacs-state--previous nil
  "Meow state before switching to EMACS state.")

(defvar my-meow-emacs-state-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-o") #'my-meow-toggle-emacs-state)
    (define-key map (kbd "M-SPC") #'meow-keypad)
    map)
  "Keymap for EMACS state.")

(meow-define-state emacs
  "原生 Emacs 态: 无 meow 绑定, 用于 gnus 等特殊 mode."
  :lighter " [E]"
  :keymap my-meow-emacs-state-keymap)

(defun my-meow-toggle-emacs-state ()
  "Toggle EMACS state."
  (interactive)
  (if (meow-emacs-mode-p)
      (meow--switch-state (or my-meow-emacs-state--previous 'motion))
    (setq my-meow-emacs-state--previous meow--current-state)
    (meow--switch-state 'emacs)))

;; ---------- 自定义 state: org-agenda (保留 evil-org agenda 键位) ----------
;; 全部键位放 state map: org-agenda-mode-map 里 g/d/c/s/[ /] 已是命令 (非前缀),
;; 多键序列 (g TAB/dd/ct/[[) 无法 define-key 到 mode map; state map 是稀疏
;; keymap, 无此限制, 且优先级高于 mode map。
(defvar my-meow-org-agenda-keymap
  (let ((map (make-sparse-keymap)))
    ;; open
    (define-key map (kbd "SPC") #'org-agenda-show-and-scroll-up)
    (define-key map (kbd "<tab>") #'org-agenda-goto)
    (define-key map (kbd "S-<return>") #'org-agenda-goto)
    (define-key map (kbd "g TAB") #'org-agenda-goto)
    (define-key map (kbd "RET") #'org-agenda-switch-to)
    (define-key map (kbd "M-RET") #'org-agenda-recenter)
    (define-key map (kbd "<delete>") #'org-agenda-show-scroll-down)
    (define-key map (kbd "<backspace>") #'org-agenda-show-scroll-down)
    ;; motion
    (define-key map (kbd "j") #'org-agenda-next-line)
    (define-key map (kbd "k") #'org-agenda-previous-line)
    (define-key map (kbd "gj") #'org-agenda-next-item)
    (define-key map (kbd "gk") #'org-agenda-previous-item)
    (define-key map (kbd "gH") (lambda () (interactive) (move-to-window-line 0)))
    (define-key map (kbd "gM") (lambda () (interactive) (move-to-window-line nil)))
    (define-key map (kbd "gL") (lambda () (interactive) (move-to-window-line -1)))
    (define-key map (kbd "C-j") #'org-agenda-next-item)
    (define-key map (kbd "C-k") #'org-agenda-previous-item)
    (define-key map (kbd "[[") #'org-agenda-earlier)
    (define-key map (kbd "]]") #'org-agenda-later)
    ;; manipulation
    (define-key map (kbd "J") #'org-agenda-priority-down)
    (define-key map (kbd "K") #'org-agenda-priority-up)
    (define-key map (kbd "H") #'org-agenda-do-date-earlier)
    (define-key map (kbd "L") #'org-agenda-do-date-later)
    (define-key map (kbd "t") #'org-agenda-todo)
    (define-key map (kbd "M-j") #'org-agenda-drag-line-forward)
    (define-key map (kbd "M-k") #'org-agenda-drag-line-backward)
    (define-key map (kbd "C-S-h") #'org-agenda-todo-previousset)
    (define-key map (kbd "C-S-l") #'org-agenda-todo-nextset)
    ;; undo
    (define-key map (kbd "u") #'org-agenda-undo)
    ;; actions
    (define-key map (kbd "dd") #'org-agenda-kill)
    (define-key map (kbd "dA") #'org-agenda-archive)
    (define-key map (kbd "da") #'org-agenda-archive-default-with-confirmation)
    (define-key map (kbd "ct") #'org-agenda-set-tags)
    (define-key map (kbd "ce") #'org-agenda-set-effort)
    (define-key map (kbd "cT") #'org-timer-set-timer)
    (define-key map (kbd "i") #'org-agenda-diary-entry)
    (define-key map (kbd "a") #'org-agenda-add-note)
    (define-key map (kbd "A") #'org-agenda-append-agenda)
    (define-key map (kbd "C") #'org-agenda-capture)
    ;; mark
    (define-key map (kbd "m") #'org-agenda-bulk-toggle)
    (define-key map (kbd "~") #'org-agenda-bulk-toggle-all)
    (define-key map (kbd "*") #'org-agenda-bulk-mark-all)
    (define-key map (kbd "%") #'org-agenda-bulk-mark-regexp)
    (define-key map (kbd "M") #'org-agenda-bulk-unmark-all)
    (define-key map (kbd "x") #'org-agenda-bulk-action)
    ;; refresh
    (define-key map (kbd "gr") #'org-agenda-redo)
    (define-key map (kbd "gR") #'org-agenda-redo-all)
    ;; quit
    (define-key map (kbd "ZQ") #'org-agenda-exit)
    (define-key map (kbd "ZZ") #'org-agenda-quit)
    ;; display
    (define-key map (kbd "gD") #'org-agenda-view-mode-dispatch)
    (define-key map (kbd "ZD") #'org-agenda-dim-blocked-tasks)
    ;; filter
    (define-key map (kbd "sc") #'org-agenda-filter-by-category)
    (define-key map (kbd "sr") #'org-agenda-filter-by-regexp)
    (define-key map (kbd "se") #'org-agenda-filter-by-effort)
    (define-key map (kbd "st") #'org-agenda-filter-by-tag)
    (define-key map (kbd "s^") #'org-agenda-filter-by-top-headline)
    (define-key map (kbd "ss") #'org-agenda-limit-interactively)
    (define-key map (kbd "S") #'org-agenda-filter-remove-all)
    ;; clock
    (define-key map (kbd "I") #'org-agenda-clock-in)
    (define-key map (kbd "O") #'org-agenda-clock-out)
    (define-key map (kbd "cg") #'org-agenda-clock-goto)
    (define-key map (kbd "cc") #'org-agenda-clock-cancel)
    (define-key map (kbd "cr") #'org-agenda-clockreport-mode)
    ;; go and show
    (define-key map (kbd ".") #'org-agenda-goto-today)
    (define-key map (kbd "gc") #'org-agenda-goto-calendar)
    (define-key map (kbd "gC") #'org-agenda-convert-date)
    (define-key map (kbd "gd") #'org-agenda-goto-date)
    (define-key map (kbd "gh") #'org-agenda-holidays)
    (define-key map (kbd "gm") #'org-agenda-phases-of-moon)
    (define-key map (kbd "gs") #'org-agenda-sunrise-sunset)
    (define-key map (kbd "gt") #'org-agenda-show-tags)
    (define-key map (kbd "p") #'org-agenda-date-prompt)
    (define-key map (kbd "P") #'org-agenda-show-the-flagging-note)
    ;; others
    (define-key map (kbd "+") #'org-agenda-manipulate-query-add)
    (define-key map (kbd "-") #'org-agenda-manipulate-query-subtract)
    (define-key map (kbd "<escape>") #'meow-last-buffer)
    map)
  "Keymap for ORG-AGENDA state (全部 agenda 键位, 原 evil-org-agenda 移植).")

(meow-define-state org-agenda
  "Agenda 专用态: 保留原 evil-org agenda 键位."
  :lighter " [A]"
  :keymap my-meow-org-agenda-keymap)

;; ---------- 各 major-mode 初始 state ----------
;; normal: 普通编辑 (prog/text 默认) / motion: 只占 j/k, 字母键穿透
;; emacs: 无 meow 绑定 / insert: 直接输入
(dolist (entry '((dired-mode . motion)
                 (vterm-mode . insert)
                 (magit-status-mode . motion)
                 (magit-log-mode . motion)
                 (magit-diff-mode . motion)
                 (org-agenda-mode . org-agenda)))
  (add-to-list 'meow-mode-state-list entry))

;; ---------- insert 态键位 (原 evil 习惯) ----------
(define-key meow-insert-state-keymap (kbd "C-g") #'meow-insert-exit) ; C-g 退 insert
(define-key meow-insert-state-keymap (kbd "C-h") #'my-simple-indent-backspace) ; C-h 退格 (按缩进单位删, 不弹 help)

;; ---------- surround (替代 evil-surround) ----------
;; 用法 (先选中内容, 再执行):
;;   SPC s s  加环绕   (提示输入字符, 如 " ' ( [ )
;;   SPC s d  删环绕   (删掉最近一层配对符号)
;;   SPC s c  改环绕
(use-package surround
  :ensure t)

;; ---------- 自定义 leader map (SPC 前缀) ----------
;; 不能把键绑进 mode-specific-map (C-c 前缀): 会与现有 C-c 绑定冲突
;; (如 C-c a=org-agenda, C-c o o=olivetti)。独立 keymap 作 meow-keypad-leader-dispatch,
;; SPC 后优先查这里, 未命中透明到 C-c (SPC c = C-c c = org-capture 等)。
(defvar my-meow-leader-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "s s") #'surround-insert)
    (define-key map (kbd "s d") #'surround-delete)
    (define-key map (kbd "s c") #'surround-change)
    map)
  "Meow leader 扩展 map (SPC 前缀, 不占用 C-c 键位).")

;; ---------- org 智能命令 (evil-org 移植, 定义在 init-org.el) ----------
;; meow 的 i/a/o 在 org 里是普通插入; 表感知/列表延续等智能行为走 SPC 前缀。
;; 非 org buffer 按这些键会提示 (my-meow-org-dispatch 保护)。
(defun my-meow-org-dispatch (cmd)
  "Return a command that runs CMD only in org-mode buffers."
  (lambda ()
    (interactive)
    (if (derived-mode-p 'org-mode)
        (call-interactively cmd)
      (user-error "该命令仅 org-mode 可用"))))

;; 注意: 绑定值若是函数调用 (lambda), 必须用 define-key 运行时求值。
(dolist (entry '((?i . my-org-insert-line)      ; 智能插入 (表感知/列表延续)
                 (?a . my-org-append-line)
                 (?o . my-org-open-below)
                 (?O . my-org-open-above)
                 (?d . my-org-delete)            ; 智能删除 (修整列表编号/标题 tags)
                 (?x . my-org-delete-char)
                 (?X . my-org-delete-backward-char)
                 (?\[ . org-backward-element)    ; element 导航 (原 gh/gl/gk/gj)
                 (?\] . org-forward-element)
                 (?{ . org-backward-paragraph)
                 (?} . org-forward-paragraph)
                 (?H . my-org-top)))             ; 最近的 1 星标题 (原 gH)
  (define-key my-meow-leader-map (vector (car entry))
    (my-meow-org-dispatch (cdr entry))))

;; SPC 后未命中的键透明转发到 C-c (mode-specific-map), 保留 SPC c/capture 等原绑定
(setq meow-keypad-leader-dispatch my-meow-leader-map)
(setq meow-keypad-leader-transparent t)

;; ---------- 行号: insert 态切绝对, 其余相对 (替代原 evil 相对行号) ----------
(meow-setup-line-number)

;; ---------- org thing (文本对象, 注册在 init-org.el) ----------
;; 用法: 光标在目标上, 按 , (inner) 或 . (bounds), 再按 thing 键:
;;   E = org element (段落/表格行/代码块)   R = subtree   G = greater element
(add-to-list 'meow-char-thing-table '(?E . org-element))
(add-to-list 'meow-char-thing-table '(?R . org-subtree))
(add-to-list 'meow-char-thing-table '(?G . org-greater))
(add-to-list 'meow-char-thing-table '(?O . org-object))

(provide 'init-meow)
;;; init-meow.el ends here
