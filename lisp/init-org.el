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
(defvar org-stuck-projects nil)           ; 同上 (定义在 org-agenda.el)
(declare-function appt-activate "appt" (&optional arg))
(declare-function org-agenda-to-appt "org-agenda" (&optional refresh filter &rest args))
(defvar org-directory "~/org")            ; 2026-09-23: 下面"确保 ~/org 存在"的顶层
                                          ;   file-exists-p 会读它, 而 :custom 里的
                                          ;   org-directory 要等 org 加载才生效
;; 注: 勿 defvar org-agenda-span — defvar 在有值时不会重置, 若置 nil 会覆盖
;; org-agenda.el 的 defcustom 默认值(week), 导致 C-c a 报 number-or-marker-p nil。
(defvar org-agenda-files '("~/org/inbox.org"      ; Agenda 只扫描任务文件 + 节假日
                           "~/org/projects.org"
                           "~/org/areas.org"
                           "~/org/habits.org"
                           "~/org/someday.org"        ; 2026-09-28 补: SOMEDAY 是关闭态
                           "~/org/gcal-holidays.org") ;   不进 TODO 池, 只有周回顾
                                                      ;   (C-c a R) 才需要它的入口
  "Agenda 文件清单。
2026-09-26: 从下面的 `:custom' 提到这里 — org 是 `:defer t' 懒加载的,
`:custom' 要等 org 本体加载才生效, 而 Dashboard 的 agenda 子进程 (ide.el)
在启动时 (org 还没加载) 就要读这个变量, 否则抛 void-variable 且卡片永远
停在 \"Loading calendar…\"。defvar 的值 org 的 defcustom 不会覆盖。
2026-09-28: 补 someday.org — 它原先在 agenda 文件之外, 后果是所有 agenda
视图都看不到 SOMEDAY 条目, 周回顾里没有入口去翻\"将来也许\"清单。")
(declare-function org-gcal-reload-client-id-secret "org-gcal.el" ())

;; ---------- org: 核心 ----------
;; Emacs 内置, 不从 ELPA 装 (避免版本冲突)
(use-package org
  :ensure nil
  ;; 启动优化 (2026-09-23): 不再在启动时加载 org 本体 (省 ~0.45s)。
  ;; 打开 .org 文件 / C-c a / C-c c 都由 autoload 触发, 感知不到差别。
  ;; 若想让 org 在启动后空闲时自动热起来, 见文件末尾注释。
  :defer t
  ;; 2026-09-27: org 默认 org-startup-truncated=t, 长行是「截断」而不是折行 —
  ;; 长段落会跑出屏幕右边 (行尾一个延续箭头)。置 nil 关掉截断, 再开
  ;; visual-line-mode: 按单词边界折行, C-n/C-p 也按屏幕行走, 不会一次跳过整段长行。
  :hook (org-mode . visual-line-mode)
  :custom
  (org-startup-indented t)                  ; 内容自动缩进对齐标题
  (org-hide-leading-stars t)                ; 隐藏前导星号 (更干净)
  (org-startup-truncated nil)               ; 长行折行显示 (默认 t = 截断)
  ;; 2026-09-27: 打开 .org 就把 [[file:...png]] 显示成图 (只对 GUI frame 有效,
  ;; 终端里看不到图, 链接照样在)。想临时关掉: C-c C-x C-v 或文件里写
  ;; #+STARTUP: noinlineimages。显示宽度上限见 org-image-max-width (默认 fill-column)。
  (org-startup-with-inline-images t)
  ;; 2026-09-27: 内置默认值是 t, 含义是「一律按原图像素宽显示」—— 于是每张图上面
  ;; 写的 #+ATTR_ORG: :width 全被无视, 只有上面的 max-width 上限管得住它。
  ;; 置 nil 改成「#+ATTR_ORG 优先 (没写就看第一个 #+ATTR_xxx), 都没有才用原图宽」,
  ;; 没写 ATTR 的图照样受 max-width 上限约束。想给没写 ATTR 的图定个默认值,
  ;; 就写 '(800) 这种列表形式。改完 ATTR 想立刻看到效果: C-c C-x C-v 关再开。
  (org-image-actual-width nil)
  (org-ellipsis " ⤵")                       ; 折叠内容显示符号
  (org-return-follows-link t)               ; 光标在链接上按 RET 打开链接 (否则换行)
  (org-directory "~/org")                    ; org 文件根目录
  (org-default-notes-file "~/org/inbox.org") ; capture 默认文件
  ;; org-agenda-files 不在这里设 — 见文件顶部 defvar (启动时就要可读)
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
;; 2026-09-23: org 懒加载后这个位置 org-mode-map 还不存在, 必须等 org 加载完再删。
;; (org-mode 每次开启不会重挂, 所以加载后删一次就够)
(with-eval-after-load 'org
  (define-key org-mode-map [menu-bar table] nil)
  (define-key org-mode-map [menu-bar org] nil)
  (define-key org-mode-map [menu-bar text] nil))

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

;; ---------- org-download: 截图 / 剪贴板图片直接进笔记 ----------
;; 截图或把图片丢进来 → 拷到「当前笔记目录/images/」→ 自动插好 [[file:images/xxx.png]]。
;; macOS 圈选截图走系统自带的 screencapture -i; 剪贴板粘贴 (org-download-clipboard)
;; 在 macOS 上依赖 homebrew 的 pngpaste, 没装会提示 "Please install the pngpaste
;; program" — 那条路可以用内置的 M-x yank-media 代替 (org 自带 image/.* handler)。
;; 注意: 终端 Emacs 不渲染图片, TTY 里只看到链接; GUI frame 才能显示。
(use-package org-download
  :after org
  :bind (:map org-mode-map
              ("C-c C-x y" . org-download-clipboard)  ; 剪贴板里的图 → images/ + 插链接
              ("C-c C-x i" . org-download-screenshot)) ; 圈选截图 (screencapture -i)
  :init
  ;; 默认会在链接上面插一行 "#+DOWNLOADED: <路径> @ <时间>"; 截图路径是 /tmp, 噪音, 关掉
  (setq org-download-annotate-function (lambda (_link) ""))
  :custom
  (org-download-image-dir "images")                     ; 相对当前笔记, 统一放 images/
  (org-download-heading-lvl nil)                        ; 不再按标题再套一层子目录
  (org-download-screenshot-method "screencapture -i %s") ; macOS 圈选截图
  :config
  (org-download-enable))                                ; 拖拽 URL/文件 交给它处理

;; ---------- org: meow 键位 (原 evil-org 移植, 2026-08 迁到 meow) ----------
;; 历史: evil-org 2022 停更 → 先用原生 evil 复刻 (my-org-* 前缀, 编译零警告),
;; 2026-08 随 evil→meow 迁移: 命令逻辑全部保留, 外壳去掉 evil 宏,
;; 绑定层改用 meow (见 lisp/init-meow.el 与本文档底部)。
;; 键位策略 (meow 穿透原则):
;;   - 组合键 (M-*/C-S-*/Tab/C-t 等) → define-key org-mode-map, meow 不拦截
;;   - 智能命令 (I/A/o/O/d/x/X, element 导航) → SPC 前缀 (leader)
;;   - 文本对象 → meow thing (, 或 . + E/R/G)
(require 'cl-lib)
;; org 本体懒加载 (见文件开头 use-package org 的 :defer t): 省启动 ~0.45s。

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
  ;; 把带时刻的 org 条目导入 appt 队列。
  ;; 2026-09-28 修: 原实现只在 org-agenda-finalize-hook 里调, 而
  ;; org-agenda-to-appt 只收集"今天"的带时刻条目 (实测: 放一条明天的 15:00
  ;; deadline → "No event to add", 队列 0 条; 换成今天 → "Added 2 events")。
  ;; 后果: 只有"当天恰好开过 agenda"的提醒才会响, 挂机几天全静默。
  ;; 现在两条路并举:
  ;;   a. 保留 finalize-hook (开 agenda 时顺手刷新, 无副作用)
  ;;   b. 加一个每 30 分钟的全量重扫 (refresh=t 清空重建), 覆盖不开 agenda 的日子
  ;; 注: appt 只能在“条目当天”提前 warn; 想让明天的 deadline 今天就提醒,
  ;;     得把 org-deadline-warning-days 传给 org-agenda-to-appt, 那是另一回事。
  (add-hook 'org-agenda-finalize-hook #'org-agenda-to-appt)
  (run-with-timer 30 (* 30 60)
                  (lambda () (interactive)
                    ;; 仅当 org 已加载才刷新: 避免为了提醒把 org 拽起来破坏懒加载。
                    ;; org 只要开过任意 .org 文件或按过 C-c c 就在了, 所以覆盖得到
                    ;; "开机挂机但没开 agenda" 的场景; 首轮刷新会顺带加载 org-agenda。
                    (when (featurep 'org)
                      (ignore-errors (org-agenda-to-appt t)))))
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
;; 2026-09-23: org 改懒加载后这一整块要延后 — org-mode-map 要等 org 加载才存在,
;; 放在加载期会在第一行 void-variable 中断, 本文件后面所有配置静默丢失。
(with-eval-after-load 'org
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
  (define-key org-mode-map (kbd "C-S-j") #'org-shiftcontroldown))
;; Tab/backtab 保留 org 默认 (org-cycle / org-shifttab), meow 穿透

;; --- org-agenda: 专用 state (meow) ---
;; 全部 agenda 键位在 init-meow.el 的 my-meow-org-agenda-keymap (org-agenda state)。
;; 原因: org-agenda-mode-map 里 g/d/c/s/[ /] 已是命令, 多键序列无法 define-key 到
;; mode map; meow 自定义 state map 是稀疏 keymap, 无前缀冲突。

;; ---------- org-capture: 快速捕获 ----------
;; C-c c 弹出模板菜单, 选模板后快速记录, 保存到对应文件
;; 2026-09-27: 加 N = 主题笔记 (每次新建一个文件, 不是往固定文件追加)。
;; 用 plain 型而非 entry 型 — entry 要求模板以 * 开头, 否则报
;; "Template is not a valid Org entry or tree", 而主题笔记需要以
;; #+TITLE / #+FILETAGS / #+STARTUP 这些文件级关键字开头。
;; file 目标给函数时会被 org-capture-expand-file funcall, 借此在选中模板后
;; 提示输入文件名 (相对路径按 org-directory 展开, 文件不存在会自动创建)。
(setq org-capture-templates
      '(("t" "任务 (TODO)" entry (file "~/org/inbox.org")
         ;; 2026-09-28 修: 属性抽屉里必须写 ":CREATED: 值", 不能写 "- Created: 值"。
         ;; 后者是无效属性行, org 会把它当普通正文 — 实测 org-entry-get "CREATED"
         ;; 返回 nil, 于是所有按创建时间排序/老化的视图永远拿不到数据。
         ;; (inbox.org 里已有两条是这么写坏的, 见该文件。)
         "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")
        ("n" "笔记" entry (file "~/org/CAPTURE-notes.org")
         "* %?\n  %U\n")
        ("l" "链接 (带来源)" entry (file "~/org/links.org")
         "* %?\n  %U\n  Source: %a\n  %i\n")
        ;; 2026-09-28: file+datetree 在新版 org 里已废弃, 每次 capture 会打印
        ;; "Deprecated date/weektree capture templates changed to
        ;; 'file+olp+datetree'."; 换成新名字, 落点结构完全一样 (实测)。
        ("j" "日记" entry (file+olp+datetree "~/org/journal.org")
         "* %?\n  %U\n")
        ("N" "主题笔记 (新建文件)" plain
         (file (lambda ()
                 ;; 已有主题可补全 (选到已有文件 = 往它末尾追加新骨架, 不是覆盖);
                 ;; 也可能直接输入候选里没有的新名字 → 新建一个主题文件。
                 (let ((name (completing-read
                              "笔记文件名 (新名字 = 新建): "
                              (mapcar #'file-name-nondirectory (my-org-note-files))
                              nil nil)))
                   (when (string-empty-p name)
                     (user-error "未输入文件名, 已取消"))
                   (expand-file-name
                    (if (string-suffix-p ".org" name) name (concat name ".org"))
                    org-directory))))
         "#+TITLE: %^{标题}\n#+FILETAGS: :%^{标签}:\n#+STARTUP: overview\n\n* %?\n")
        ;; 2026-09-28: R = 收藏链接。从 Elfeed 里按 R 直接调用 (见 init-qol.el),
        ;; 靠 elfeed-link + org-store-link 把标题/链接/作者填进下面的占位符。
        ("R" "收藏链接 (读出)" entry (file+headline "~/org/feeds.org" "收藏")
         "* [[%:external-link][%:title]]\n  :PROPERTIES:\n  :CREATED: %U\n  :END:\n  来源: %:feed-title / 作者: %:authors\n")))

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
;;   C-c C-x C-d   在文件里显示各子树累计耗时
;;   M-x org-clock-report   插入时间报告 (clocktable)
;;   注: Emacs 30 的 org 里 C-c C-x C-r 是 radio button, 不是时间报告
;; 时间报告模板 (光标放 #+BEGIN 行上按 C-c C-c 刷新):
;;   #+BEGIN: clocktable :scope agenda :maxlevel 2 :block thisweek
;;   #+END:
(setq org-clock-in-switch-to-state "DOING"    ; 打卡时任务自动转 DOING
      org-clock-out-remove-zero-time-clocks t ; 零时长记录自动清除
      org-clock-persist t)                    ; 重启 Emacs 后恢复打卡状态
;; 必须等 org 加载后再调 (它是 org-clock 的 autoload, 提前调会把 org-clock
;; 连同 org 一起拉起来, 破坏懒加载)
(with-eval-after-load 'org
  (org-clock-persistence-insinuate))

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
  :defer t
  :commands (org-gcal-sync org-gcal-fetch org-gcal-post-at-point
             org-gcal-delete-at-point org-gcal-sync-tokens-clear)
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

;; ---------- org-archive: 完成的项目/任务归档到哪 ----------
;; 2026-09-28 补: projects.org 的说明里一直写着"整个子树 C-c C-x C-a 归档到
;; archive.org", 但本文件从没设过 org-archive-location —— 于是实际走的是 org
;; 默认值 "%s_archive::", 即归档进 `projects.org_archive`。文档和真实行为对不上,
;; 按文档意图补齐, 统一进 ~/org/archive.org 的日期树 (datetree), 按年月归档好翻。
;;
;; 注: 这是全局设置, agenda 里的 dA 也走这里。想改回"每文件各存一份", 把那行注掉
;; (或设回 "%s_archive::") 即可。archive.org 不在 org-agenda-files 里,
;; 归档进去的东西不会污染任何 agenda 视图 (和其它 gcal*.org 一样)。
(setq org-archive-location (concat (expand-file-name "archive.org" org-directory)
                                   "::datetree/"))

;; ---------- 自定义 agenda 视图 ----------
;; C-c a n = 人生管理主视图: 本周日程 (含习惯图) + 所有未完成任务
;; C-c a R = 周回顾: 一次拉齐 GTD 周回顾要翻的全部清单 (见下)
;; 其他内置视图: C-c a a (完整 agenda) / C-c a t (所有 TODO)
;;
;; 2026-09-28 变更 (GTD 补全):
;;   1. `todo "NEXT|TODO|DOING|HOLD"` → `tags-todo "-habit/NEXT|TODO|DOING|HOLD"`。
;;      原写法把 habits.org 的重复习惯也塞进"未完成任务", 每天刷屏;
;;      `tags-todo` 的 match 语法是 "排除标签/待办关键字", "-habit" 正好滤掉习惯。
;;      (注: `todo` 块的额外选项里放 `org-agenda-tag-filter-preset` 无效 — 实测
;;       过滤器根本没应用; tags-todo 是文档规定的正路。)
;;   2. 补 C-c a R 周回顾 + C-c a i 收件箱清零两个视图。
;;      周回顾对应 journal.org 里那张手工 checklist, 现在一条命令拉全:
;;        ① 本周日程 → ② 行动池 → ③ 等待 → ④ 僵死项目 → ⑤ 全部项目 → ⑥ 将来也许
;;      ④ 僵死项目需要 org-stuck-projects (见下方), 否则 stuck 块直接报错。
(setq org-agenda-custom-commands
      '(("n" "本周 + 待办"
         ((agenda "" ((org-agenda-span 7)
                      (org-agenda-overriding-header "本周日程")))
          (tags-todo "-habit/NEXT|TODO|DOING|HOLD"
                     ((org-agenda-overriding-header "未完成任务 (不含习惯)")))))
        ("w" "等待中"
         ((todo "WAIT"
                ((org-agenda-overriding-header "等待别人回复 (WAIT)")))))
        ("R" "周回顾 (Weekly Review)"
         ((agenda "" ((org-agenda-span 7)
                      (org-agenda-overriding-header "① 本周日程")))
          (tags-todo "-habit/NEXT|TODO|DOING|HOLD"
                     ((org-agenda-overriding-header "② 行动池 (下一步行动)")))
          (todo "WAIT"
                ((org-agenda-overriding-header "③ 等待中: 有结果了吗? 要催吗?")))
          (stuck ""
                 ((org-agenda-overriding-header "④ 僵死项目: 没有任何下一步行动")))
          (tags "+project+LEVEL=1"
                ((org-agenda-overriding-header "⑤ 全部项目 (每个都还有下一步吗?)")))
          (todo "SOMEDAY"
                ((org-agenda-overriding-header "⑥ 将来也许: 升级/删除/留着")))))
        ("i" "收件箱清零"
         ((todo nil ((org-agenda-files '("~/org/inbox.org"))
                     (org-agenda-overriding-header
                      "① inbox.org: 每条 C-c C-w 归位或删除, 目标清零")))))))

;; ---------- org-stuck-projects: 僵死项目判据 ----------
;; C-c a R 的 ④ 依赖它; 不配则 stuck 块报
;; "Missing information to identify unstuck projects"。
;; 默认值 ("+LEVEL=2/-DONE" ...) 对本库是错的: 它把 projects.org 的 2 级描述行
;; (如 "目标: 上海, ...") 当项目, 实测匹配到的是那行, 不是项目本身。
;;
;; 判据四段: ① 匹配器 ② 子树上出现哪些 TODO 关键字算"不僵死" ③ 标签 ④ 反选正则。
;;   ① "+project+LEVEL=1"   = 带 :project: 标签的一级标题 (本库项目就是这种)
;;   ② ("*")               = 子树里有任何非关闭状态的 TODO 关键字就不僵死。
;;                            org 会把 "*" 展开成所有 not-done 关键字
;;                            (实测 = NEXT/TODO/DOING/WAIT/HOLD, 不含 SOMEDAY)。
;;   ④ ""                  = 不用反选正则。
;; 注: projects.org 的"说明"已改成 #+begin_comment 块 (2026-09-28), 不再是一个
;;     带 :project: 的一级标题, 所以这里不必再排除它。若哪天又把它改回标题,
;;     记得给 ④ 写上 "^\\*+ 说明"。
(setq org-stuck-projects '("+project+LEVEL=1" ("*") nil ""))

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
;; C-c i = 笔记总入口 (my-org-note-open, 见下方"笔记总入口"一节)
;; C-c I = 笔记索引页 index.org (my-org-note-index)

;; ---------- 笔记索引自动重建 ----------
;; 保存 ~/org/ 下笔记文件时, 自动重建 ~/org/index.org (笔记总入口)。
;; 跨文件跳标题链接: [[file:路径::*标题][显示名]]
(defcustom my-org-index-exclude-files
  '("index.org" "inbox.org" "projects.org" "areas.org" "habits.org"
    "someday.org" "gcal.org" "gcal-holidays.org" "archive.org"
    "feeds.org")                       ; 2026-09-28: elfeed 收藏存档, 不进笔记索引
  "不进笔记索引的文件名 (任务类/日历类 + index 自身 + elfeed 收藏)。除此外 ~/org/ 下所有 .org 自动索引。"
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

;; ---------- 笔记总入口: 一个命令进出所有主题笔记 ----------
;; 组织方式: 每个主题一个文件 (~/org/主题.org), 但入口只有一个 —— C-c i
;;   选已有主题      → 直接打开那个文件 (补全文件名, 不会拼错/写重)
;;   ＋ 新建主题…    → 走 capture 模板 N (提示文件名/标题/标签, 自动建骨架)
;;   ⌂ 全部主题一览  → 打开 index.org (自动生成的全部标题索引)
;; C-c I = 直接跳到那份索引页 (不经菜单), 打开前顺手重建一遍
(defcustom my-org-note-exclude-files
  '("CAPTURE-notes.org" "links.org" "journal.org")
  "不算主题笔记的文件 (capture 落点): 不进 C-c i 候选, 但仍进索引。"
  :type '(repeat string)
  :group 'org)

(defun my-org-note-files ()
  "返回主题笔记文件列表 (绝对路径): ~/org 下笔记文件去掉 capture 落点。"
  (seq-remove (lambda (f)
                (member (file-name-nondirectory f) my-org-note-exclude-files))
              (my-org-index-files)))

(defun my-org-note-open ()
  "笔记总入口: 挑一个已有主题笔记打开, 或新建一个主题 (C-c i)。"
  (interactive)
  (let* ((names (mapcar #'file-name-nondirectory (my-org-note-files)))
         (all "⌂ 全部主题一览 (index.org)")
         (new "＋ 新建主题…")
         (choice (completing-read "主题笔记: " (append (list all new) names) nil t)))
    (cond
     ((equal choice all) (my-org-note-index))
     ((equal choice new) (org-capture nil "N"))
     (t (find-file (expand-file-name choice org-directory))))))

(defun my-org-note-index ()
  "打开笔记索引 index.org (全部主题的一览页), 打开前重建一遍 (C-c I)。"
  (interactive)
  (let* ((file (expand-file-name "index.org" org-directory))
         (buf (get-file-buffer file)))
    (cond
     ;; 索引开着且没改动 → 重建后原地刷新, 避免出现"文件已在磁盘上改变"的提示
     ((and buf (not (buffer-modified-p buf)))
      (my-org-rebuild-index)
      (with-current-buffer buf (revert-buffer t t))
      (pop-to-buffer buf))
     ;; 索引开着且你正在改它 → 只切过去, 不动磁盘 (保存时 after-save-hook 会跳过它)
     (buf
      (pop-to-buffer buf)
      (message "index.org 有未保存的改动, 这次没重建索引"))
     ;; 没开着 → 先重建再打开
     (t
      (my-org-rebuild-index)
      (find-file file)))))

(global-set-key (kbd "C-c i") #'my-org-note-open)
(global-set-key (kbd "C-c I") #'my-org-note-index)

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
  :defer t                       ; 首次按 C-c r 时才加载 (启动省 ~0.5s, 2026-08-14)
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
