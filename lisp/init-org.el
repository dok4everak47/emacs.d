;;; init-org.el --- Org Mode (笔记/任务/文学编程) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; org: Emacs 杀手级应用 — 大纲/任务管理/笔记/文学编程/文档导出
;; org-modern: 现代化外观 (符号替代星号, TODO 彩色标签)
;; evil 键位: 原 evil-org 移植 (gh/gj/gk/gl 元素导航, Tab 折叠, 文本对象)
;;
;; 全局键: C-c a (agenda) / C-c c (capture) / C-c l (存链接)
;; 文件目录: ~/org/ (inbox.org / notes.org / journal.org)

;;; Code:

;; 编译期声明: 变量在 org 各子模块加载后才定义 (use-package :custom 编译期扫描到)
(defvar org-export-with-toc nil)
(defvar org-export-with-section-numbers nil)
(defvar org-capture-templates nil)
(defvar org-clock-in-switch-to-state nil)
(defvar org-clock-out-remove-zero-time-clocks nil)
(defvar org-clock-persist nil)
(defvar org-agenda-custom-commands nil)   ; org-agenda lazy-load 前需声明 (定义在 org-agenda.el)
;; 注: 勿 defvar org-agenda-span — defvar 在有值时不会重置, 若置 nil 会覆盖
;; org-agenda.el 的 defcustom 默认值(week), 导致 C-c a 报 number-or-marker-p nil。
(declare-function org-gcal-reload-client-id-secret "org-gcal.el" ())

;; ---------- org: 核心 ----------
;; Emacs 内置, 不从 ELPA 装 (避免版本冲突)
(use-package org
  :ensure nil
  :custom
  (org-startup-indented t)                  ; 内容自动缩进对齐标题
  (org-hide-leading-stars t)                ; 隐藏前导星号 (更干净)
  (org-ellipsis " ⤵")                       ; 折叠内容显示符号
  (org-return-follows-link t)               ; 光标在链接上按 RET 打开链接 (否则换行)
  (org-directory "~/org")                    ; org 文件根目录
  (org-default-notes-file "~/org/inbox.org") ; capture 默认文件
  (org-agenda-files '("~/org/inbox.org"   ; Agenda 只扫描任务文件 + 节假日
                      "~/org/projects.org"
                      "~/org/areas.org"
                      "~/org/habits.org"
                      "~/org/gcal-holidays.org"))
  (org-log-done 'time)                      ; 完成任务时记录时间戳
  (org-todo-keywords                        ; 任务状态流转 (GTD)
   ;; NEXT=下一步行动 / TODO=待澄清 / DOING=进行中 / WAIT=等待别人
   ;; HOLD=暂停 / DONE=完成 / CANC=取消 / SOMEDAY=将来也许 (| 后=关闭状态,
   ;; 不进待办视图; SOMEDAY 放单独文件 someday.org, 周回顾时翻)
   '((sequence "NEXT(n)" "TODO(t)" "DOING(i)" "WAIT(w)" "HOLD(h)"
               "|" "DONE(d)" "CANC(c)" "SOMEDAY(s)")))
  (org-use-fast-todo-selection t)           ; 切换状态时用快捷键选择
  :config
  ;; org-tempo: 结构模板展开
  ;; 输入 <s Tab → #+begin_src ... #+end_src
  ;; 其他: <e (example) <q (quote) <v (verse) <c (center) <l (latex) <h (html)
  (require 'org-tempo nil t)
  ;; org-babel: 代码块执行 (类似 Jupyter Notebook)
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((python . t)
     (shell . t)
     (emacs-lisp . t)))
  ;; 导出时不提示确认代码执行
  (setq org-confirm-babel-evaluate nil)
  ;; 导出选项
  (setq org-export-with-toc t               ; 导出含目录
        org-export-with-section-numbers nil)) ; 不加章节编号 (1. 1.1)

;; ---------- 隐藏 org 菜单栏多余菜单 (2026-08-12) ----------
;; org-mode-map 的 menu-bar 挂了 Table / Org / Text 三个菜单,
;; 用户要精简菜单栏 (功能快捷键照常, 只去菜单项)。
;; 直接 define-key 删除 menu-bar 子键最可靠 (easy-menu-remove-menu 需 emacs-menu 加载)。
;; 放加载时执行即可, org-mode-map 此时已存在; org-mode 每次开启不会重挂。
(define-key org-mode-map [menu-bar table] nil)
(define-key org-mode-map [menu-bar org] nil)
(define-key org-mode-map [menu-bar text] nil)

;; ---------- org-modern: 现代化外观 ----------
;; 用 Unicode 符号替代星号标题, TODO 关键字彩色背景, 标签美化
(use-package org-modern
  :ensure t
  :after org
  :hook (org-mode . org-modern-mode)
  :custom
  (org-modern-star 'replace)               ; 用符号替代 * ** *** 星号
  (org-modern-list '((43 . "◦")            ; + → ◦
                     (45 . "–")            ; - → –
                     (42 . "•")))           ; * → •
  (org-modern-todo-faces
   `(("NEXT"   . (:background "#61afef" :foreground "#282c34" :weight bold))
     ("TODO"  . (:background "#e06c75" :foreground "#282c34" :weight bold))
     ("DOING" . (:background "#e5c07b" :foreground "#282c34" :weight bold))
     ("WAIT"  . (:background "#d19a66" :foreground "#282c34" :weight bold))
     ("HOLD"  . (:background "#c678dd" :foreground "#282c34" :weight bold))
     ("DONE"  . (:background "#98c379" :foreground "#282c34" :weight bold))
     ("CANC"  . (:background "#5c6370" :foreground "#282c34" :weight bold))
     ("SOMEDAY" . (:background "#5c6370" :foreground "#abb2bf" :weight bold)))))

;; ---------- org: meow 键位 (原 evil-org 移植, 2026-08 迁到 meow) ----------
;; 历史: evil-org 2022 停更 → 先用原生 evil 复刻 (my-org-* 前缀, 编译零警告),
;; 2026-08 随 evil→meow 迁移: 命令逻辑全部保留, 外壳去掉 evil 宏,
;; 绑定层改用 meow (见 lisp/init-meow.el 与本文档底部)。
;; 键位策略 (meow 穿透原则):
;;   - 组合键 (M-*/C-S-*/Tab/C-t 等) → define-key org-mode-map, meow 不拦截
;;   - 智能命令 (I/A/o/O/d/x/X, element 导航) → SPC 前缀 (leader)
;;   - 文本对象 → meow thing (, 或 . + E/R/G)
(require 'cl-lib)
(require 'org)

;; ---------- org-agenda: 懒加载 ----------
;; 不 require (启动省 ~60ms), 首次用 C-c a 才加载。
;; 变量 org-agenda-custom-commands 已在顶部 defvar 声明 (避免本文件下方 setq 报
;; void-variable); 实际定义在 org-agenda.el, lazy 加载后生效。
;; 注意: 勿 defvar org-agenda-span (见顶部注释) — 它靠 org-agenda.el 的 defcustom 设默认值。
;; meow 的 org-agenda state 用 symbol 引用 (#'org-agenda-*), 运行时解析, 不受影响。
(use-package org-agenda
  :ensure nil
  :commands (org-agenda org-agenda-list org-agenda-capture)
  :defer t
  :config
  (require 'org-habit)
  ;; ---------- Appointment 主动提醒 (弹 macOS 系统通知) ----------
  ;; org 自身不主动提醒, 靠 appt: 把带"具体时刻"的 DEADLINE:/SCHEDULED: 条目
  ;; 导入 appt 队列, 到点前调用函数发 macOS 通知 (即使焦点在别的 app 也弹)。
  ;; ⚠️ 前提: Emacs 需保持运行 (appt 是 Emacs 内 timer)。
  ;; appt 调用本函数时传 (min-to-app new-time appt-msg) 三参, appt-msg 是要显示的消息(可能是列表)。
  (defun my-org-appt-notify (min-to-app new-time appt-msg)
    "Appt 触发: 发 macOS 系统通知 (标题=提醒, 内容=appt 消息)."
    (let ((msgs (if (listp appt-msg) appt-msg (list appt-msg))))
      (dolist (m msgs)
        (when (and m (stringp m) (not (string-empty-p m)))
          (start-process "my-org-appt-notify" nil
                         "osascript" "-e"
                         (format "display notification %S with title %S sound name \"Glass\""
                                 m
                                 "⏰ Emacs 提醒"))))))
  ;; 提前 10 分钟提醒; 之后每 5 分钟重提醒一次
  (setq appt-message-warning-time 10
        appt-display-interval 5)
  ;; 用自定义的 macOS 通知函数替代默认弹窗
  (setq appt-disp-window-function #'my-org-appt-notify)
  ;; 打开 agenda 时把带时刻的 org 条目导入 appt 队列
  (add-hook 'org-agenda-finalize-hook #'org-agenda-to-appt)
  ;; 激活 appt 计时器
  (appt-activate 1))

;; --- 表感知的句子移动 (原 evil-org-forward/backward-sentence) ---
(defun my-org-forward-sentence (count)
  "In a table go to next cell, otherwise go to next sentence."
  (interactive "p")
  (if (org-at-table-p)
      (org-table-end-of-field count)
    (forward-sentence count)))
(defun my-org-backward-sentence (count)
  "In a table go to previous cell, otherwise go to previous sentence."
  (interactive "p")
  (if (org-at-table-p)
      (org-table-beginning-of-field count)
    (backward-sentence count)))

;; --- 行首/行尾 (org-special-ctrl-a/e 兼容) ---
(defalias 'my-org-beginning-of-line 'org-beginning-of-line)
(defun my-org-end-of-line (&optional n)
  "Like org-end-of-line but honors org-special-ctrl-a/e."
  (interactive "p")
  (org-end-of-line n))

;; --- gH: 最近的 1 星标题 (原 evil-org-top) ---
(defun my-org-top ()
  "Find the nearest one-star heading."
  (interactive)
  (while (org-up-heading-safe)))

;; --- 插入命令: I/A/o/O 结构感知 (原 evil-org-insert-line 等) ---
(defun my-org-insert-line ()
  "Insert at beginning of line; on headings/items after the markers."
  (interactive)
  (if (org-at-heading-or-item-p)
      (progn (beginning-of-line)
             (org-beginning-of-line nil)
             (meow-insert))
    (progn (back-to-indentation)
           (meow-insert))))
(defun my-org-append-line ()
  "Append at end of line; on headings before tags."
  (interactive)
  (if (org-at-heading-p)
      (progn (end-of-line)
             (org-end-of-line nil)
             (meow-insert))
    (progn (end-of-line)
           (meow-insert))))
(defun my-org-open-below ()
  "Clever insertion: continue table rows and list items (like evil-org-open-below)."
  (interactive)
  (cond ((org-at-table-p)
         (org-table-insert-row '(4))
         (meow-insert))
        ((and (org-at-item-p)
              (progn (end-of-visible-line)
                     (org-insert-item (org-at-item-checkbox-p))))
         (meow-insert))
        ((meow-open-below))))
(defun my-org-open-above ()
  "Clever insertion: continue table rows and list items (like evil-org-open-above)."
  (interactive)
  (cond ((org-at-table-p)
         (org-table-insert-row)
         (meow-insert))
        ((and (org-at-item-p)
              (progn (beginning-of-line)
                     (org-insert-item (org-at-item-checkbox-p))))
         (meow-insert))
        ((meow-open-above))))
(defmacro my-org-define-eol-command (cmd)
  "Return a function that executes CMD at eol and enters insert state."
  (let ((newcmd (intern (concat "my-org-" (symbol-name cmd) "-below"))))
    `(progn
       (defun ,newcmd ()
         ,(concat "Execute `" (symbol-name cmd) "' at eol, then insert.")
         (interactive)
         (end-of-visible-line)
         (call-interactively #',cmd)
         (meow-insert))
       #',newcmd)))

;; 生成 C-RET / C-S-RET 用的行尾插入命令 (顶层定义, 编译器可识别)
(my-org-define-eol-command org-insert-heading-respect-content)
(my-org-define-eol-command org-insert-todo-heading-respect-content)

;; --- < >: 升降级/缩进/表格列移动 (原 evil-org-> / evil-org-<) ---
(defun my-org-indent-items (beg end count)
  "Indent all selected items in itemlist (negative COUNT dedents)."
  (when (null count) (setq count 1))
  (let* ((struct (save-excursion (goto-char beg) (org-list-struct)))
         (region-p (region-active-p)))
    (if (and struct org-list-automatic-rules (not region-p)
             (= (line-beginning-position) (org-list-get-top-point struct)))
        (org-list-indent-item-generic count nil struct)
      (save-excursion
        (when region-p (deactivate-mark))
        (set-mark beg)
        (goto-char end)
        (org-list-indent-item-generic count t struct)))))
(defun my-org-table-move-column (beg end arg)
  "Move org table column: ARG > 0 moves column BEG to END, ARG < 0 the reverse."
  (let* ((text (buffer-substring beg end))
         (n-cells-selected (max 1 (cl-count ?| text)))
         (n-columns-to-move (* n-cells-selected (abs arg)))
         (move-left-p (< arg 0)))
    (goto-char (if move-left-p end beg))
    (dotimes (_ n-columns-to-move) (org-table-move-column move-left-p))))
(defun my-org-> (count)
  "Demote/indent/move right: headings, code blocks, tables. 作用于选中区域 (无选区时当前行)。"
  (interactive "p")
  (let ((beg (if (region-active-p) (region-beginning) (line-beginning-position)))
        (end (if (region-active-p) (region-end) (line-end-position))))
    (cond
     ((org-with-limited-levels
       (or (org-at-heading-p)
           (save-excursion (goto-char beg) (org-at-heading-p))))
      (if (> count 0)
          (org-map-region 'org-do-demote beg end)
        (org-map-region 'org-do-promote beg end)))
     ((and (org-at-table-p)
           (save-excursion
             (goto-char beg)
             (<= (line-beginning-position) end (line-end-position))))
      (my-org-table-move-column beg end count))
     ((and (org-at-item-p)
           (<= end (save-excursion (org-end-of-item-list))))
      (my-org-indent-items beg end count))
     (t
      (when (and (org-at-table-p)
                 (< beg (org-table-begin)))
        (setq beg (min beg (org-table-begin)))
        (setq end (max end (org-table-end))))
      (indent-rigidly beg end count)))))
(defun my-org-< (count)
  "Promote/dedent/move left; see `my-org->'."
  (interactive "p")
  (my-org-> (- count)))

;; --- d/x/X: 删除后修整列表编号与标题 tags (原 evil-org-delete 等) ---
(defun my-org-delete ()
  "Like kill-region, but realigns tags and numbered lists. 作用于选中区域 (无选区时当前行)。"
  (interactive)
  (let* ((beg (if (region-active-p) (region-beginning) (line-beginning-position)))
         (end (if (region-active-p) (region-end) (line-end-position)))
         (renumber-lists-p (or (< beg (line-beginning-position))
                               (> end (line-end-position)))))
    (kill-region beg end)
    (cond ((and renumber-lists-p (org-at-item-p))
           (org-list-repair))
          ((org-at-heading-p)
           (org-fix-tags-on-the-fly)))))
(defun my-org-delete-char (count)
  "Delete char (or region if active), combining with org-delete-char."
  (interactive "p")
  (if (region-active-p)
      (kill-region (region-beginning) (region-end))
    (org-delete-char count)))
(defun my-org-delete-backward-char (count)
  "Delete backward char (or region if active), combining with org-delete-char."
  (interactive "p")
  (if (region-active-p)
      (kill-region (region-beginning) (region-end))
    (org-delete-backward-char count)))

;; --- textobjects → meow thing (原 evil-org textobjects theme) ---
;; meow 的 thing 函数返回 (beg . end) cons; 无 count 参数, 扩展用 meow 数字键。
;; 用法: 光标在目标上, 按 , (inner) 或 . (bounds), 再按 E/R/G/O:
;;   E = element (段落/表格行/代码块)   R = subtree   G = greater element   O = object
(defun my-org-select-an-element (element)
  "Select an org ELEMENT (bounds 含前后 blank 行)."
  (list (org-element-property :begin element)
        (org-element-property :end element)))
(defun my-org-select-inner-element (element)
  "Select inner org ELEMENT."
  (let ((type (org-element-type element))
        (begin (org-element-property :begin element))
        (end (org-element-property :end element))
        (contents-begin (org-element-property :contents-begin element))
        (contents-end (org-element-property :contents-end element))
        (post-affiliated (org-element-property :post-affiliated element))
        (post-blank (org-element-property :post-blank element)))
    (cond ((or (string-suffix-p "-block" (symbol-name type))
               (memq type '(latex-environment)))
           (list (org-with-point-at post-affiliated (line-beginning-position 2))
                 (org-with-point-at end (line-beginning-position (- post-blank)))))
          ((memq type '(verbatim code))
           (list (1+ begin) (- end post-blank 1)))
          ('otherwise
           (list (or contents-begin post-affiliated begin)
                 (or contents-end
                     (org-with-point-at end
                       (if (memq type org-element-all-objects)
                           (- end post-blank)
                         (line-end-position (- post-blank))))))))))
(defun my-org-parent (element)
  "Find a parent or nearest heading of ELEMENT."
  (or (org-element-property :parent element)
      (save-excursion
        (goto-char (org-element-property :begin element))
        (if (org-with-limited-levels (org-at-heading-p))
            (org-up-heading-safe)
          (org-with-limited-levels (org-back-to-heading)))
        (org-element-at-point))))

;; --- thing 包装: (list beg end) → (cons beg . end) ---
(defun my-org--thing-cons (r)
  (cons (nth 0 r) (nth 1 r)))

;; O: org object (urls, table cells)
(defun my-org--inner-object ()
  (my-org--thing-cons
   (my-org-select-inner-element (org-element-context))))
(defun my-org--bounds-object ()
  (my-org--thing-cons
   (my-org-select-an-element (org-element-context))))

;; E: org element (paragraphs, table rows, code blocks)
(defun my-org--inner-element ()
  (my-org--thing-cons
   (my-org-select-inner-element (org-element-at-point))))
(defun my-org--bounds-element ()
  (my-org--thing-cons
   (my-org-select-an-element (org-element-at-point))))

;; G: greater (recursive) org element: tables, list items, subtrees
(defun my-org--inner-greater ()
  (save-excursion
    (let ((element (org-element-at-point)))
      (unless (memq (cl-first element) org-element-greater-elements)
        (setq element (my-org-parent element)))
      (my-org--thing-cons
       (my-org-select-inner-element element)))))
(defun my-org--bounds-greater ()
  (save-excursion
    (let ((element (org-element-at-point)))
      (unless (memq (cl-first element) org-element-greater-elements)
        (setq element (my-org-parent element)))
      (my-org--thing-cons
       (my-org-select-an-element element)))))

;; R: org subtree
(defun my-org--at-subtree-heading ()
  (org-with-limited-levels
   (cond ((org-at-heading-p) (beginning-of-line))
         ((org-before-first-heading-p) (user-error "Not in a subtree"))
         (t (outline-previous-visible-heading 1)))))
(defun my-org--inner-subtree ()
  (my-org--at-subtree-heading)
  (my-org--thing-cons
   (my-org-select-inner-element (org-element-at-point))))
(defun my-org--bounds-subtree ()
  (my-org--at-subtree-heading)
  (my-org--thing-cons
   (my-org-select-inner-element (org-element-at-point))))

(meow-thing-register 'org-object #'my-org--inner-object #'my-org--bounds-object)
(meow-thing-register 'org-element #'my-org--inner-element #'my-org--bounds-element)
(meow-thing-register 'org-greater #'my-org--inner-greater #'my-org--bounds-greater)
(meow-thing-register 'org-subtree #'my-org--inner-subtree #'my-org--bounds-subtree)

;; --- 键位: 组合键直接绑 org-mode-map (meow 穿透, 不拦截组合键) ---
;; 单字母键 (i/a/o/d/x/w/e/b...) 走 meow 原生布局; 智能命令走 SPC 前缀 (见 init-meow.el)
(define-key org-mode-map (kbd "$") #'my-org-end-of-line)
(define-key org-mode-map (kbd ")") #'my-org-forward-sentence)
(define-key org-mode-map (kbd "(") #'my-org-backward-sentence)
(define-key org-mode-map (kbd "}") #'org-forward-paragraph)
(define-key org-mode-map (kbd "{") #'org-backward-paragraph)
(define-key org-mode-map (kbd "<") #'my-org-<)
(define-key org-mode-map (kbd ">") #'my-org->)
(define-key org-mode-map (kbd "C-RET") #'my-org-org-insert-heading-respect-content-below)
(define-key org-mode-map (kbd "C-S-RET") #'my-org-org-insert-todo-heading-respect-content-below)
(define-key org-mode-map (kbd "C-t") #'org-metaright)
(define-key org-mode-map (kbd "C-d") #'org-metaleft)
(define-key org-mode-map (kbd "M-h") #'org-metaleft)
(define-key org-mode-map (kbd "M-l") #'org-metaright)
(define-key org-mode-map (kbd "M-k") #'org-metaup)
(define-key org-mode-map (kbd "M-j") #'org-metadown)
(define-key org-mode-map (kbd "M-H") #'org-shiftmetaleft)
(define-key org-mode-map (kbd "M-L") #'org-shiftmetaright)
(define-key org-mode-map (kbd "M-K") #'org-shiftmetaup)
(define-key org-mode-map (kbd "M-J") #'org-shiftmetadown)
(define-key org-mode-map (kbd "C-S-h") #'org-shiftcontrolleft)
(define-key org-mode-map (kbd "C-S-l") #'org-shiftcontrolright)
(define-key org-mode-map (kbd "C-S-k") #'org-shiftcontrolup)
(define-key org-mode-map (kbd "C-S-j") #'org-shiftcontroldown)
;; Tab/backtab 保留 org 默认 (org-cycle / org-shifttab), meow 穿透

;; --- org-agenda: 专用 state (meow) ---
;; 全部 agenda 键位在 init-meow.el 的 my-meow-org-agenda-keymap (org-agenda state)。
;; 原因: org-agenda-mode-map 里 g/d/c/s/[ /] 已是命令, 多键序列无法 define-key 到
;; mode map; meow 自定义 state map 是稀疏 keymap, 无前缀冲突。

;; ---------- org-capture: 快速捕获 ----------
;; C-c c 弹出模板菜单, 选模板后快速记录, 保存到对应文件
(setq org-capture-templates
      '(("t" "任务 (TODO)" entry (file "~/org/inbox.org")
         "* TODO %?\n  :PROPERTIES:\n  - Created: %U\n  :END:\n")
        ("n" "笔记" entry (file "~/org/CAPTURE-notes.org")
         "* %?\n  %U\n")
        ("l" "链接 (带来源)" entry (file "~/org/links.org")
         "* %?\n  %U\n  Source: %a\n  %i\n")
        ("j" "日记" entry (file+datetree "~/org/journal.org")
         "* %?\n  %U\n")))

;; ---------- org-table: 纯文本电子表格 ----------
;; 快速上手 (org 文件里直接敲, 无需任何配置):
;;   | 项目 | 数量 | 单价 |  合计 |
;;   |------+------+------+-------|
;;   | A    |    2 |   10 |    20 |
;;   | B    |    3 |   15 |    45 |
;;   | 总计 |      |      |    65 |
;;   #+TBLFM: $4=$2*$3 :: @5$4=vsum(@2..@4)
;; 操作:
;;   TAB/RET       移动单元格 (自动建新行)
;;   C-c '         单元格区域编辑 (类似 Excel 点击编辑)
;;   C-c C-c       重算所有公式
;; 公式语法: $4=$2*$3 列引用, @2..@4 行区间, vsum()/vmean() 聚合
;; 自动重算默认已开启 (org-table-allow-automatic-line-recalculation)

;; ---------- org-clock: 任务计时 (打卡) ----------
;; 用法: 光标在任务标题上打卡 (C-c a agenda 里用 I / O 更快)
;;   C-c C-x C-i   开始计时 (任务自动转 DOING)
;;   C-c C-x C-o   结束计时
;;   C-c C-x C-r   插入时间报告 (clocktable)
;; 时间报告模板 (光标放 #+BEGIN 行上按 C-c C-c 刷新):
;;   #+BEGIN: clocktable :scope agenda :maxlevel 2 :block thisweek
;;   #+END:
(setq org-clock-in-switch-to-state "DOING"    ; 打卡时任务自动转 DOING
      org-clock-out-remove-zero-time-clocks t ; 零时长记录自动清除
      org-clock-persist t)                    ; 重启 Emacs 后恢复打卡状态
(org-clock-persistence-insinuate)

;; ---------- org-gcal: Google Calendar 双向同步 ----------
;; 把 Google 日历事件拉进 ~/org/gcal.org (随 agenda 一起显示),
;; 在 org 里改/建条目也能推回 Google 日历。
;; 凭据: 填在 gcal-client.el (gitignore, 不入库) — 申请步骤见该文件头注释
;; 用法:
;;   M-x org-gcal-fetch         拉取日历 → ~/org/gcal.org (增量, 保留 org 侧修改)
;;   M-x org-gcal-sync          拉取 + 把 org 侧修改推回日历
;;   M-x org-gcal-post-at-point 把光标处的 org 条目作为新事件推送到日历
;;   M-x org-gcal-delete-at-point 删除光标处条目对应的日历事件
;;   M-x org-gcal-sync-tokens-clear  重置同步 token (换日历/出问题时)
;; 首次 fetch 会打开浏览器做 Google OAuth 授权, token 存 ~/.emacs.d/org-gcal/
;; 新增日历: 在 fetch-file-alist 里加 ("日历ID" . "~/org/gcal-xxx.org")
;;   日历 ID 获取: Google Calendar 网页 → 设置 → 日历集成 → 日历 ID
;;   主日历 ID 固定是 "primary" (或自己的 Gmail 地址)
(use-package org-gcal
  :ensure t
  :after org
  :init
  ;; token 用 plstore 加密存储, 需要本地 GPG 密钥
  ;; 首次配置: gpg --batch --gen-key 生成无口令密钥, 邮箱固定 emacs-plstore@localhost
  (setq plstore-encrypt-to '("emacs-plstore@localhost"))
  ;; 预填充 org-generic-id-locations, 避免 org-gcal 每次启动 require
  ;; org-generic-id.el 时重复打印 "Loading org-generic-id-locations on
  ;; first load." 并重新 load 数据文件 (包内判断在文件加载中执行, hash
  ;; 恒为空, 故永远触发; 这里先塞入数据让 defvar 保留已有值)
  (let ((loc-file (expand-file-name
                   ".org-generic-id-locations" user-emacs-directory)))
    (when (and (file-exists-p loc-file)
               (not (boundp 'org-generic-id-locations)))
      (setq org-generic-id-locations (make-hash-table :test 'equal))
      (with-temp-buffer
        (condition-case nil
            (progn
              (insert-file-contents loc-file)
              (dolist (item (read (current-buffer)))
                (puthash (car item) (cdr item) org-generic-id-locations)))
          (error nil)))))
  ;; 加载 OAuth 凭据 — 必须在 require 之前 (包加载时检查 client-id/secret, 否则启动警告)
  (let ((cred (expand-file-name "gcal-client.el" user-emacs-directory)))
    (when (file-exists-p cred)
      (load cred)))
  :config
  ;; 有凭据才注册 OAuth provider (org-gcal 加载后自行调用 reload 也可, 这里兜底)
  (when (and (boundp 'org-gcal-client-id) org-gcal-client-id
             (boundp 'org-gcal-client-secret) org-gcal-client-secret)
    (org-gcal-reload-client-id-secret))
  ;; 日历 → org 文件映射 (primary = Google 主日历, 即 Gmail 地址的默认日历)
  (setq org-gcal-fetch-file-alist
        '(("primary" . "~/org/gcal.org")
          ("zh.china#holiday@group.v.calendar.google.com" . "~/org/gcal-holidays.org"))))

;; ---------- org-refile: 收集箱 → 项目归档 ----------
;; 整理流程: C-c c t 捕获 → inbox.org → 光标在条目上 C-c C-w 归档到项目/领域
;; 归档目标 = 所有 agenda 文件的 1-2 级标题 (projects.org 的项目名正好是 1 级)
;; 用 org-refile-use-outline-path 显示"文件/标题"路径, 选起来更清楚
(setq org-refile-targets '((org-agenda-files :maxlevel . 2))
      org-refile-use-outline-path 'file
      org-outline-path-complete-in-steps nil)

;; ---------- 自定义 agenda 视图 ----------
;; C-c a n = 人生管理主视图: 本周日程 (含习惯图) + 所有未完成任务
;; 其他内置视图: C-c a a (完整 agenda) / C-c a t (所有 TODO)
(setq org-agenda-custom-commands
      '(("n" "本周 + 待办"
         ((agenda "" ((org-agenda-span 7)
                      (org-agenda-overriding-header "本周日程")))
          (todo "NEXT|TODO|DOING|HOLD"
                ((org-agenda-overriding-header "未完成任务")))))
        ("w" "等待中"
         ((todo "WAIT"
                ((org-agenda-overriding-header "等待别人回复 (WAIT)")))))))

;; ---------- org-habit: 习惯追踪 ----------
;; 习惯条目: TODO + SCHEDULED: <日期 .+1d> (每天) / .+1w (每周)
;; 在 agenda 视图里显示习惯图 (●●○○○○○), 标记 DONE 自动推进到下一周期
;; 注: org-habit 内部 require org-agenda, 加载时会连带拉起 org-agenda,
;; 故 org-habit 也一并 lazy (在 org-agenda 的 use-package :config 里 require)。
(setq org-habit-graph-column 80)          ; 习惯图起始列 (给任务名留空间)

;; ---------- 全局快捷键 ----------
(global-set-key (kbd "C-c a") #'org-agenda)         ; 日程/任务总览
(global-set-key (kbd "C-c c") #'org-capture)        ; 快速捕获
(global-set-key (kbd "C-c l") #'org-store-link)      ; 存储链接 (org 文件可插入)

;; ---------- 笔记索引自动重建 ----------
;; 保存 ~/org/ 下笔记文件时, 自动重建 ~/org/index.org (笔记总入口)。
;; 跨文件跳标题链接: [[file:路径::*标题][显示名]]
(defcustom my-org-index-exclude-files
  '("index.org" "inbox.org" "projects.org" "areas.org" "habits.org"
    "someday.org" "gcal.org" "gcal-holidays.org")
  "不进笔记索引的文件名 (任务类/日历类 + index 自身)。除此外 ~/org/ 下所有 .org 自动索引。"
  :type '(repeat string)
  :group 'org)

(defun my-org-index-files ()
  "返回参与索引的笔记文件 (绝对路径): ~/org/ 下所有 .org,
排除 my-org-index-exclude-files 和 Emacs 锁定文件 (.# 开头)。"
  (let (out)
    (dolist (f (directory-files org-directory t "\\.org\\'"))
      (let ((name (file-name-nondirectory f)))
        (unless (or (member name my-org-index-exclude-files)
                    (string-prefix-p ".#" name))
          (push f out))))
    (nreverse out)))

(defun my-org-index--headings (file)
  "返回 FILE 的干净标题列表 (跳过空标题和'说明'条目)。
用 org 库解析, 自动剥离 TODO 状态关键字和标签 (含中文标签, 比手写正则可靠)。
跳过 #+begin_.../#+end_... 结构块, 避免块内伪标题污染索引。"
  (let (out)
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (org-mode)
        (goto-char (point-min))
        (while (not (eobp))
          (cond
           ;; 跳过结构块 (#+begin_src/#+begin_example ... #+end_...), 块内 * 不是标题
           ((looking-at "^#\\+begin_\\([a-z]+\\)")
            (let ((kw (match-string 1)))
              (forward-line 1)
              (when (re-search-forward (concat "^#\\+end_" kw "[ \t]*$") nil t)
                (forward-line 1))))
           ;; 处理标题行
           ((looking-at "^*+[ \t]")
            ;; org-heading-components 返回 (level todo todo-type priority title tags)
            (let* ((comps (org-heading-components))
                   (title (nth 4 comps)))
              (when (and title
                         (not (string-empty-p (string-trim title)))
                         (not (string-prefix-p "说明" (string-trim title))))
                (push (string-trim title) out)))
            (forward-line 1))
           (t (forward-line 1)))))
      (nreverse out))))

(defun my-org-rebuild-index ()
  "重建 ~/org/index.org: 汇总笔记文件的标题, 生成跨文件跳转链接。"
  (interactive)
  (let ((lines (list "#+title: 笔记索引 (Notes Index)"
                     "#+STARTUP: content"
                     ""
                     "* 使用说明"
                     "  自动重建: 保存 ~/org 下笔记文件时更新。C-c C-o 打开链接。"
                     "  任务类 (projects/inbox/habits/areas/someday) 由 Agenda 管理, 不在索引。")))
    ;; 笔记文件标题 (自动扫描, 排除任务/日历类)
    (dolist (file (my-org-index-files))
      (let ((hs (my-org-index--headings file)))
        (when hs
          (setq lines (append lines
                              (list "" (format "* %s" (file-name-nondirectory file)))))
          (dolist (h hs)
            (setq lines (append lines (list (format "  - [[file:%s::*%s][%s]]" file h h))))))))
    ;; 附录: 全部笔记 org 文件 (与正文同集, 用 ~/org/ 相对形式)
    (setq lines (append lines '("" "* 附录: 全部笔记文件快速跳转")))
    (dolist (f (my-org-index-files))
      (let* ((rel (file-relative-name f (expand-file-name org-directory)))
             (target (concat (file-name-as-directory org-directory) rel)))
        (setq lines (append lines (list (format "  - [[file:%s][%s]]" target rel))))))
    (with-temp-buffer
      (insert (mapconcat #'identity lines "\n") "\n")
      (write-file (expand-file-name "index.org" org-directory)))
    (message "笔记索引已重建")))

(defun my-org-maybe-rebuild-index ()
  "保存 ~/org 下笔记文件后自动重建索引 (跳过任务/日历类和 index 自身, 避免循环)。"
  (let ((f (and (buffer-file-name)
                (expand-file-name (buffer-file-name)))))
    (when (and f
               (string-prefix-p (expand-file-name org-directory) f)
               (not (member (file-name-nondirectory f) my-org-index-exclude-files)))
      (my-org-rebuild-index))))

(add-hook 'after-save-hook #'my-org-maybe-rebuild-index)

;; ---------- 确保 org 目录存在 ----------
(unless (file-exists-p org-directory)
  (make-directory org-directory t))

;; ---------- org-roam: 笔记网络 (Zettelkasten) ----------
;; 独立目录 ~/org-roam/, 完全隔离现有 ~/org/ (任务/agenda/index 不受影响)。
;; org-roam 默认目录就是 ~/org-roam/, 数据库在 ~/.emacs.d/org-roam.db (Emacs 30 内置 sqlite)。
;; 反向链接在 normal 态下的 buffer 底部显示 (哪些笔记引用了当前笔记)。
;; ⚠️ 前缀用 C-c r (roam), 因为 C-c n 已被 my-open-line-below (init-lazycat) 占用。
(use-package org-roam
  :ensure t
  :bind (("C-c r i" . org-roam-node-insert)   ; 插入指向某笔记的链接
         ("C-c r f" . org-roam-node-find)      ; 按标题查找笔记
         ("C-c r c" . org-roam-capture)        ; 捕获新笔记
         ("C-c r r" . org-roam-ref-find))      ; 按引用查找
  :custom
  (org-roam-directory (expand-file-name "~/org-roam/"))
  (org-roam-db-gc-threshold 1000)            ; 数据库 GC 阈值
  (org-roam-mode-sections '(org-roam-backlinks-section
                            org-roam-reflinks-section)) ; 底部显示反向链接
  :config
  ;; org-roam-db-autosync-mode: 自动同步数据库 (增删改自动更新)
  (org-roam-db-autosync-mode +1))

(provide 'init-org)
;;; init-org.el ends here
