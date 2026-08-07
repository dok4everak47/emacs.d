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

;; ---------- org: 核心 ----------
;; Emacs 内置, 不从 ELPA 装 (避免版本冲突)
(use-package org
  :ensure nil
  :custom
  (org-startup-indented t)                  ; 内容自动缩进对齐标题
  (org-hide-leading-stars t)                ; 隐藏前导星号 (更干净)
  (org-ellipsis " ⤵")                       ; 折叠内容显示符号
  (org-directory "~/org")                    ; org 文件根目录
  (org-default-notes-file "~/org/inbox.org") ; capture 默认文件
  (org-agenda-files '("~/org"))             ; agenda 搜索目录
  (org-log-done 'time)                      ; 完成任务时记录时间戳
  (org-todo-keywords                        ; 任务状态流转
   '((sequence "TODO(t)" "DOING(i)" "HOLD(h)" "|" "DONE(d)" "CANC(c)")))
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
   `(("TODO"  . (:background "#e06c75" :foreground "#282c34" :weight bold))
     ("DOING" . (:background "#e5c07b" :foreground "#282c34" :weight bold))
     ("HOLD"  . (:background "#c678dd" :foreground "#282c34" :weight bold))
     ("DONE"  . (:background "#98c379" :foreground "#282c34" :weight bold))
     ("CANC"  . (:background "#5c6370" :foreground "#282c34" :weight bold)))))

;; ---------- org: evil 键位 (原 evil-org 移植, 该包 2022 停更 → 自维护) ----------
;; evil-collection 的 org 支持故意保持基础 (官方注释: NOT intended to
;; supersede evil-org-mode), 因此这里用原生 evil 复刻原 evil-org 主题
;; '(navigation insert textobjects additional) + base + agenda 的全部键位,
;; 行为与旧版一致, 但不再依赖停更的 evil-org 包 (编译零警告)。
;; 自维护函数统一 my-org- 前缀。
(require 'cl-lib)
(require 'evil)
(require 'org)
(require 'org-agenda)

;; 把 org 的移动命令声明为 evil motion (支持 d{motion} 等)
(dolist (fn '(org-beginning-of-line org-end-of-line
              org-forward-sentence org-backward-sentence
              org-forward-paragraph org-backward-paragraph
              org-forward-element org-backward-element
              org-up-element org-down-element))
  (evil-declare-motion fn))

;; --- 表感知的句子移动 (原 evil-org-forward/backward-sentence) ---
(evil-define-motion my-org-forward-sentence (count)
  "In a table go to next cell, otherwise go to next sentence."
  :type exclusive :jump t
  (interactive "p")
  (if (org-at-table-p)
      (org-table-end-of-field count)
    (evil-forward-sentence-begin count)))
(evil-define-motion my-org-backward-sentence (count)
  "In a table go to previous cell, otherwise go to previous sentence."
  :type exclusive :jump t
  (interactive "p")
  (if (org-at-table-p)
      (org-table-beginning-of-field count)
    (evil-backward-sentence-begin count)))

;; --- 行首/行尾 (org-special-ctrl-a/e 兼容) ---
(defalias 'my-org-beginning-of-line 'org-beginning-of-line)
(evil-define-motion my-org-end-of-line (&optional n)
  "Like org-end-of-line but honors org-special-ctrl-a/e in evil."
  (when (and org-special-ctrl-a/e
             evil-move-cursor-back
             (not evil-move-beyond-eol)
             (memq evil-state '(normal visual operator))
             (not (invisible-p (line-end-position)))
             (= (point) (1- (line-end-position))))
    (forward-char))
  (org-end-of-line n))

;; --- gH: 最近的 1 星标题 (原 evil-org-top) ---
(evil-define-motion my-org-top ()
  "Find the nearest one-star heading."
  :type exclusive :jump t
  (while (org-up-heading-safe)))

;; --- 插入命令: I/A/o/O 结构感知 (原 evil-org-insert-line 等) ---
(defun my-org-insert-line (count)
  "Insert at beginning of line; on headings/items after the markers."
  (interactive "p")
  (if (org-at-heading-or-item-p)
      (progn (beginning-of-line)
             (org-beginning-of-line nil)
             (evil-insert count))
    (evil-insert-line count)))
(defun my-org-append-line (count)
  "Append at end of line; on headings before tags."
  (interactive "p")
  (if (org-at-heading-p)
      (progn (end-of-line)
             (org-end-of-line nil)
             (evil-insert count))
    (evil-append-line count)))
(defun my-org-open-below (count)
  "Clever insertion: continue table rows and list items (like evil-org-open-below)."
  (interactive "P")
  (cond ((org-at-table-p)
         (org-table-insert-row '(4))
         (evil-insert nil))
        ((and (org-at-item-p)
              (progn (end-of-visible-line)
                     (org-insert-item (org-at-item-checkbox-p))))
         (evil-insert nil))
        ((evil-open-below count))))
(defun my-org-open-above (count)
  "Clever insertion: continue table rows and list items (like evil-org-open-above)."
  (interactive "P")
  (cond ((org-at-table-p)
         (org-table-insert-row)
         (evil-insert nil))
        ((and (org-at-item-p)
              (progn (beginning-of-line)
                     (org-insert-item (org-at-item-checkbox-p))))
         (evil-insert nil))
        ((evil-open-above count))))
(defmacro my-org-define-eol-command (cmd)
  "Return a function that executes CMD at eol and enters insert state."
  (let ((newcmd (intern (concat "my-org-" (symbol-name cmd) "-below"))))
    `(progn
       (defun ,newcmd ()
         ,(concat "Execute `" (symbol-name cmd) "' at eol, then insert.")
         (interactive)
         (end-of-visible-line)
         (call-interactively #',cmd)
         (evil-insert nil))
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
(evil-define-operator my-org-> (beg end count)
  "Demote/indent/move right: headings, code blocks, tables."
  :move-point nil
  (interactive "<r><vc>")
  (when (null count) (setq count 1))
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
    (when (and (not (region-active-p)) (org-at-table-p))
      (setq beg (min beg (org-table-begin)))
      (setq end (max end (org-table-end))))
    (evil-shift-right beg end count))))
(evil-define-operator my-org-< (beg end count)
  "Promote/dedent/move left; see `my-org->'."
  (interactive "<r><vc>")
  (my-org-> beg end (- (or count 1))))

;; --- d/x/X: 删除后修整列表编号与标题 tags (原 evil-org-delete 等) ---
(evil-define-operator my-org-delete (beg end type register yank-handler)
  "Like evil-delete, but realigns tags and numbered lists."
  (interactive "<R><x><y>")
  (let ((renumber-lists-p (or (< beg (line-beginning-position))
                              (> end (line-end-position)))))
    (evil-delete beg end type register yank-handler)
    (cond ((and renumber-lists-p (org-at-item-p))
           (org-list-repair))
          ((org-at-heading-p)
           (org-fix-tags-on-the-fly)))))
(evil-define-operator my-org-delete-char (count beg end type register)
  "Combine evil-delete-char with org-delete-char."
  :motion evil-forward-char
  (interactive "p<R><x>")
  (if (evil-visual-state-p)
      (evil-delete-char beg end type register)
    (evil-set-register ?- (filter-buffer-substring beg end))
    (evil-yank beg end type register)
    (org-delete-char count)))
(evil-define-operator my-org-delete-backward-char (count beg end type register)
  "Combine evil-delete-backward-char with org-delete-char."
  :motion evil-backward-char
  (interactive "p<R><x>")
  (if (evil-visual-state-p)
      (evil-delete-backward-char beg end type register)
    (evil-set-register ?- (filter-buffer-substring beg end))
    (evil-yank beg end type register)
    (org-delete-char count)))

;; --- textobjects (原 evil-org textobjects theme) ---
(defun my-org-select-an-element (element)
  "Select an org ELEMENT."
  (list (min (region-beginning) (org-element-property :begin element))
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
(evil-define-text-object my-org-an-object (count beg end type)
  "An org object (urls, table cells)."
  (when (null end) (setq end (point)))
  (when (null beg) (setq beg (point)))
  (let* ((first (org-element-context))
         (element first))
    (goto-char end)
    (when (<= (org-element-property :end element) end)
      (setq element (org-element-context)))
    (dotimes (_ (1- count))
      (goto-char (org-element-property :end element))
      (setq element (org-element-context)))
    (my-org-select-an-element element)))
(evil-define-text-object my-org-inner-object (count &optional beg end type)
  "Select an org object (urls, table cells)."
  (my-org-select-inner-element (org-element-context)))
(evil-define-text-object my-org-an-element (count &optional beg end type)
  "An org element (paragraphs, table rows, code blocks)."
  (let* ((first (org-element-at-point))
         (element first))
    (when (and end (>= end (org-element-property :end element)))
      (org-forward-element)
      (setq element (org-element-at-point)))
    (dotimes (_ (1- count))
      (org-forward-element)
      (setq element (org-element-at-point)))
    (my-org-select-an-element element)))
(evil-define-text-object my-org-inner-element (count &optional beg end type)
  "Inner org element."
  (my-org-select-inner-element (org-element-at-point)))
(evil-define-text-object my-org-a-greater-element (count &optional beg end type)
  "A greater (recursive) org element: tables, list items, subtrees."
  :type line
  (when (null count) (setq count 1))
  (save-excursion
    (when beg (goto-char beg))
    (let ((element (org-element-at-point)))
      (when (or (not (memq (cl-first element) org-element-greater-elements))
                (and end (>= end (org-element-property :end element))))
        (setq element (my-org-parent element)))
      (dotimes (_ (1- count))
        (setq element (my-org-parent element)))
      (my-org-select-an-element element))))
(evil-define-text-object my-org-inner-greater-element (count &optional beg end type)
  "Inner greater (recursive) org element."
  (when (null count) (setq count 1))
  (save-excursion
    (when beg (goto-char beg))
    (let ((element (org-element-at-point)))
      (unless (memq (cl-first element) org-element-greater-elements)
        (setq element (my-org-parent element)))
      (dotimes (_ (1- count))
        (setq element (my-org-parent element)))
      (my-org-select-inner-element element))))
(evil-define-text-object my-org-a-subtree (count &optional beg end type)
  "An org subtree."
  :type line
  (when (null count) (setq count 1))
  (org-with-limited-levels
   (cond ((org-at-heading-p) (beginning-of-line))
         ((org-before-first-heading-p) (user-error "Not in a subtree"))
         (t (outline-previous-visible-heading 1))))
  (when count (while (and (> count 1) (org-up-heading-safe)) (cl-decf count)))
  (my-org-select-inner-element (org-element-at-point)))
(evil-define-text-object my-org-inner-subtree (count &optional beg end type)
  "Inner org subtree."
  :type line
  (when (null count) (setq count 1))
  (org-with-limited-levels
   (cond ((org-at-heading-p) (beginning-of-line))
         ((org-before-first-heading-p) (user-error "Not in a subtree"))
         (t (outline-previous-visible-heading 1))))
  (when count (while (and (> count 1) (org-up-heading-safe)) (cl-decf count)))
  (my-org-select-inner-element (org-element-at-point)))

;; --- 键位: base + navigation + insert + textobjects + additional ---
(evil-define-key 'motion org-mode-map
  "0" 'my-org-beginning-of-line
  "$" 'my-org-end-of-line
  ")" 'my-org-forward-sentence
  "(" 'my-org-backward-sentence
  "}" 'org-forward-paragraph
  "{" 'org-backward-paragraph
  "gh" 'org-up-element
  "gl" 'org-down-element
  "gk" 'org-backward-element
  "gj" 'org-forward-element
  "gH" 'my-org-top)
(evil-define-key 'normal org-mode-map
  "I" 'my-org-insert-line
  "A" 'my-org-append-line
  "o" 'my-org-open-below
  "O" 'my-org-open-above
  "d" 'my-org-delete
  "x" 'my-org-delete-char
  "X" 'my-org-delete-backward-char
  (kbd "<C-return>") 'my-org-org-insert-heading-respect-content-below
  (kbd "<C-S-return>") 'my-org-org-insert-todo-heading-respect-content-below)
(evil-define-key '(normal visual) org-mode-map
  (kbd "<tab>") 'org-cycle
  "g TAB" 'org-cycle
  (kbd "<backtab>") 'org-shifttab
  "<" 'my-org-<
  ">" 'my-org->)
(evil-define-key '(visual operator) org-mode-map
  "ae" 'my-org-an-object
  "ie" 'my-org-inner-object
  "aE" 'my-org-an-element
  "iE" 'my-org-inner-element
  "ir" 'my-org-inner-greater-element
  "ar" 'my-org-a-greater-element
  "aR" 'my-org-a-subtree
  "iR" 'my-org-inner-subtree)
(evil-define-key 'insert org-mode-map
  (kbd "C-t") 'org-metaright
  (kbd "C-d") 'org-metaleft)
(evil-define-key '(normal visual) org-mode-map
  (kbd "M-h") 'org-metaleft
  (kbd "M-l") 'org-metaright
  (kbd "M-k") 'org-metaup
  (kbd "M-j") 'org-metadown
  (kbd "M-H") 'org-shiftmetaleft
  (kbd "M-L") 'org-shiftmetaright
  (kbd "M-K") 'org-shiftmetaup
  (kbd "M-J") 'org-shiftmetadown
  (kbd "C-S-h") 'org-shiftcontrolleft
  (kbd "C-S-l") 'org-shiftcontrolright
  (kbd "C-S-k") 'org-shiftcontrolup
  (kbd "C-S-j") 'org-shiftcontroldown)

;; --- org-agenda: motion 态 + 原 evil-org-agenda 键位 ---
(evil-set-initial-state 'org-agenda-mode 'motion)
(evil-define-key 'motion org-agenda-mode-map
  ;; open
  (kbd "<tab>") 'org-agenda-goto
  (kbd "S-<return>") 'org-agenda-goto
  "g TAB" 'org-agenda-goto
  (kbd "RET") 'org-agenda-switch-to
  (kbd "M-RET") 'org-agenda-recenter
  (kbd "SPC") 'org-agenda-show-and-scroll-up
  (kbd "<delete>") 'org-agenda-show-scroll-down
  (kbd "<backspace>") 'org-agenda-show-scroll-down
  ;; motion
  "j" 'org-agenda-next-line
  "k" 'org-agenda-previous-line
  "gj" 'org-agenda-next-item
  "gk" 'org-agenda-previous-item
  "gH" 'evil-window-top
  "gM" 'evil-window-middle
  "gL" 'evil-window-bottom
  (kbd "C-j") 'org-agenda-next-item
  (kbd "C-k") 'org-agenda-previous-item
  (kbd "[[") 'org-agenda-earlier
  (kbd "]]") 'org-agenda-later
  ;; manipulation
  "J" 'org-agenda-priority-down
  "K" 'org-agenda-priority-up
  "H" 'org-agenda-do-date-earlier
  "L" 'org-agenda-do-date-later
  "t" 'org-agenda-todo
  (kbd "M-j") 'org-agenda-drag-line-forward
  (kbd "M-k") 'org-agenda-drag-line-backward
  (kbd "C-S-h") 'org-agenda-todo-previousset
  (kbd "C-S-l") 'org-agenda-todo-nextset
  ;; undo
  "u" 'org-agenda-undo
  ;; actions
  "dd" 'org-agenda-kill
  "dA" 'org-agenda-archive
  "da" 'org-agenda-archive-default-with-confirmation
  "ct" 'org-agenda-set-tags
  "ce" 'org-agenda-set-effort
  "cT" 'org-timer-set-timer
  "i" 'org-agenda-diary-entry
  "a" 'org-agenda-add-note
  "A" 'org-agenda-append-agenda
  "C" 'org-agenda-capture
  ;; mark
  "m" 'org-agenda-bulk-toggle
  "~" 'org-agenda-bulk-toggle-all
  "*" 'org-agenda-bulk-mark-all
  "%" 'org-agenda-bulk-mark-regexp
  "M" 'org-agenda-bulk-unmark-all
  "x" 'org-agenda-bulk-action
  ;; refresh
  "gr" 'org-agenda-redo
  "gR" 'org-agenda-redo-all
  ;; quit
  "ZQ" 'org-agenda-exit
  "ZZ" 'org-agenda-quit
  ;; display
  "gD" 'org-agenda-view-mode-dispatch
  "ZD" 'org-agenda-dim-blocked-tasks
  ;; filter
  "sc" 'org-agenda-filter-by-category
  "sr" 'org-agenda-filter-by-regexp
  "se" 'org-agenda-filter-by-effort
  "st" 'org-agenda-filter-by-tag
  "s^" 'org-agenda-filter-by-top-headline
  "ss" 'org-agenda-limit-interactively
  "S" 'org-agenda-filter-remove-all
  ;; clock
  "I" 'org-agenda-clock-in
  "O" 'org-agenda-clock-out
  "cg" 'org-agenda-clock-goto
  "cc" 'org-agenda-clock-cancel
  "cr" 'org-agenda-clockreport-mode
  ;; go and show
  "." 'org-agenda-goto-today
  "gc" 'org-agenda-goto-calendar
  "gC" 'org-agenda-convert-date
  "gd" 'org-agenda-goto-date
  "gh" 'org-agenda-holidays
  "gm" 'org-agenda-phases-of-moon
  "gs" 'org-agenda-sunrise-sunset
  "gt" 'org-agenda-show-tags
  "p" 'org-agenda-date-prompt
  "P" 'org-agenda-show-the-flagging-note
  ;; others
  "+" 'org-agenda-manipulate-query-add
  "-" 'org-agenda-manipulate-query-subtract)

;; ---------- org-capture: 快速捕获 ----------
;; C-c c 弹出模板菜单, 选模板后快速记录, 保存到对应文件
(setq org-capture-templates
      '(("t" "任务 (TODO)" entry (file "~/org/inbox.org")
         "* TODO %?\n  :PROPERTIES:\n  - Created: %U\n  :END:\n")
        ("n" "笔记" entry (file "~/org/notes.org")
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
  :config
  ;; token 用 plstore 加密存储, 需要本地 GPG 密钥
  ;; 首次配置: gpg --batch --gen-key 生成无口令密钥, 邮箱固定 emacs-plstore@localhost
  (setq plstore-encrypt-to '("emacs-plstore@localhost"))
  ;; 加载 OAuth 凭据 (文件不存在则跳过, 不报错)
  (let ((cred (expand-file-name "gcal-client.el" user-emacs-directory)))
    (when (file-exists-p cred)
      (load cred)))
  ;; 有凭据才注册 OAuth provider; 没有时静默, 配置好重启即生效
  (when (and (boundp 'org-gcal-client-id) org-gcal-client-id
             (boundp 'org-gcal-client-secret) org-gcal-client-secret)
    (org-gcal-reload-client-id-secret))
  ;; 日历 → org 文件映射 (primary = Google 主日历, 即 Gmail 地址的默认日历)
  (setq org-gcal-fetch-file-alist
        '(("primary" . "~/org/gcal.org")
          ("zh.china#holiday@group.v.calendar.google.com" . "~/org/gcal-holidays.org"))))

;; ---------- 全局快捷键 ----------
(global-set-key (kbd "C-c a") #'org-agenda)         ; 日程/任务总览
(global-set-key (kbd "C-c c") #'org-capture)        ; 快速捕获
(global-set-key (kbd "C-c l") #'org-store-link)      ; 存储链接 (org 文件可插入)

;; ---------- 确保 org 目录存在 ----------
(unless (file-exists-p org-directory)
  (make-directory org-directory t))

(provide 'init-org)
;;; init-org.el ends here
