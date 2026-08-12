;;; init-dashboard.el --- 自写 Dashboard 主页 (双栏 home screen) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; 替代 emacs-dashboard 包, 自写双栏 home screen (2026-08 重构 v3)。
;; 设计原则: Dashboard 是"个人工作台首页", 只做概览不堆信息:
;;   - Today's Agenda: 只显示摘要 (时间+文件 / Habits ×N / → Open Agenda)
;;   - TODO:           只显示最重要 N 条 (• 标题, 超出显示 +N more)
;;   - Recent Files:   N 条, 过滤临时文件
;;   - Projects:       去重, 最多 N 个
;;   - 四宫格固定尺寸 (列宽+行数可调), 真正对齐
;;   - 整个 Dashboard 按 frame 宽度动态居中
;;   - 隐藏行号/cursor/mode-line (buffer-local)
;;
;; 数据源:
;;   - Today's Agenda: org-agenda-list (真实生成, 只取摘要)
;;   - TODO:            org-todo-list "NEXT|TODO|DOING|HOLD"
;;   - Recent Files:    recentf-list (过滤临时/不存在)
;;   - Projects:        projectile-known-projects (折叠空格去重)
;;
;; 布局 (用户 mockup):
;;                         EMACS
;;              📅 Agenda  📥 Inbox  ＋ Capture  ✉ Mail
;;             ┌──────────────┐  ┌──────────────┐
;;             │ Today's      │  │ TODO         │
;;             │ Agenda       │  │ • 更新简历   │
;;             └──────────────┘  └──────────────┘
;;             ┌──────────────┐  ┌──────────────┐
;;             │ Recent Files │  │ Projects     │
;;             └──────────────┘  └──────────────┘
;;                         Happy hacking!

;;; Code:

(defgroup my-dashboard nil
  "自写 Dashboard 主页."
  :group 'emacs)

(defcustom my-dash-buffer-name "*My Dashboard*"
  "Dashboard buffer 名."
  :type 'string :group 'my-dashboard)

;; ---- 布局尺寸 (可调) ----
(defcustom my-dash-col-width 40
  "每栏内容列宽 (字符数, 含边框)."
  :type 'integer :group 'my-dashboard)

(defcustom my-dash-block-rows 8
  "每个 box 内容区行数 (固定高度, 不足补空行, 超出截断)."
  :type 'integer :group 'my-dashboard)

(defcustom my-dash-todo-count 5
  "TODO 区最多显示条数."
  :type 'integer :group 'my-dashboard)

(defcustom my-dash-recents-count 5
  "Recent Files 最多显示条数."
  :type 'integer :group 'my-dashboard)

(defcustom my-dash-projects-count 5
  "Projects 最多显示条数."
  :type 'integer :group 'my-dashboard)

(defcustom my-dash-v-offset 2
  "垂直偏移 (正数=内容下移, 负数=上移)."
  :type 'integer :group 'my-dashboard)

;; ---------- 数据提取 ----------

(defun my-dash-agenda-summary ()
  "返回 Today's Agenda 摘要 (字符串行列表).
只提取带具体时刻的非习惯条目 + 习惯计数. 格式: '22:00 Inbox' / '      Scheduled: ...'."
  (let ((buf (get-buffer-create " *my-dash-agenda*"))
        lines (habits 0) (items '()))
    (with-current-buffer buf
      (erase-buffer)
      (condition-case nil (org-agenda-list) (error nil))
      (setq lines (split-string
                   (buffer-substring-no-properties (point-min) (point-max))
                   "\n" t)))
    (kill-buffer buf)
    (dolist (l lines)
      (cond
       ;; 习惯条目 → 计数
       ((string-match "habit" l) (cl-incf habits))
       ;; 带具体时刻的条目 → 解析 "file: 22:00 ... Scheduled: ..."
       ((string-match
         "^[[:space:]]*\\([A-Za-z0-9_-]+\\):[[:space:]]*\\([0-9][0-9]:[0-9][0-9]\\)[^:]*:[[:space:]]*\\(.*\\)"
         l)
        (let ((file (match-string 1 l))
              (time (match-string 2 l))
              (rest (string-trim (match-string 3 l))))
          (push (format "%s %s" time (capitalize file)) items)
          (when (not (string-empty-p rest))
            (push (format "   %s" rest) items))))))
    ;; 组装: Habits 计数 + 条目 (条目反转回原顺序)
    (let ((result '()))
      (when (> habits 0)
        (push (format "Habits × %d" habits) result))
      (append result (reverse items)))))

(defun my-dash-todo-summary ()
  "返回 TODO 摘要 (最多 my-dash-todo-count 条, 格式 '• 标题')."
  (let ((buf (get-buffer-create " *my-dash-todo*"))
        lines (out '()) (total 0))
    (with-current-buffer buf
      (erase-buffer)
      (condition-case nil (org-todo-list "NEXT|TODO|DOING|HOLD") (error nil))
      (setq lines (split-string
                   (buffer-substring-no-properties (point-min) (point-max))
                   "\n" t)))
    (kill-buffer buf)
    (dolist (l lines)
      (let* ((trimmed (string-trim l))
             (m (string-match
                 "^[A-Za-z0-9_-]+:[[:space:]]+\\(NEXT\\|TODO\\|DOING\\|HOLD\\)[[:space:]]+\\(.*\\)"
                 trimmed)))
        (when m
          (cl-incf total)
          (let* ((ti (match-string 2 trimmed))
                 (ti (replace-regexp-in-string "[[:space:]]*:[^[:space:]:]+:+[[:space:]]*$" "" ti))
                 (ti (string-trim ti)))
            (when (not (string-empty-p ti))
              (push ti out))))))
    ;; 取前 N 条 + "+N more" (more 放列表尾部)
    (let* ((rev (reverse out))
           (shown (cl-subseq rev 0 (min my-dash-todo-count (length rev))))
           (result (mapcar (lambda (x) (concat "• " x)) shown)))
      (when (> total my-dash-todo-count)
        (setq result (append result
                             (list (format "+ %d more" (- total my-dash-todo-count))))))
      result)))

(defun my-dash-recents-lines ()
  "返回最近文件 basename 列表 (过滤不存在/临时文件), 最多 my-dash-recents-count 条."
  (let ((out '()))
    (dolist (f recentf-list)
      (when (and (< (length out) my-dash-recents-count)
                 (file-exists-p f)
                 (not (string-match "/tmp/" f))
                 (not (string-match "/\\.cache/" f))
                 (not (string-match "appt\\.txt" f)))
        (push (file-name-nondirectory (directory-file-name f)) out)))
    (reverse out)))

(defun my-dash-projects-lines ()
  "返回项目 basename 列表 (折叠空格去重), 最多 my-dash-projects-count 个."
  (when (fboundp 'projectile-known-projects)
    (let ((out '()) seen)
      (dolist (p (ignore-errors (projectile-known-projects)))
        (let* ((name (file-name-nondirectory (directory-file-name p)))
               (key (replace-regexp-in-string "[[:space:]]+" " " name)))
          (when (and (< (length out) my-dash-projects-count)
                     (not (member key seen)))
            (push name out)
            (push key seen))))
      (reverse out))))

;; ---------- 渲染 ----------

(defun my-dash-block (title lines)
  "渲染一个内容块为固定尺寸的行列表.
总高 = my-dash-block-rows 内容行 + 2 边框. 内容不足补空行, 超出截断."
  (let* ((w my-dash-col-width)
         (fill (lambda (s)
                 (let ((ts (truncate-string-to-width (or s "") (- w 4) nil nil t)))
                   (concat "│ " ts
                           (make-string (max 0 (- (- w 4) (string-width ts))) ?\s)
                           " │"))))
         (border (concat "┌" (make-string (- w 2) ?─) "┐"))
         (bottom (concat "└" (make-string (- w 2) ?─) "┘")))
    (append (list border (funcall fill title))
            (mapcar fill (append (cl-subseq lines 0 (min my-dash-block-rows (length lines)))
                                 (make-list (max 0 (- my-dash-block-rows (min my-dash-block-rows (length lines)))) "")))
            (list bottom))))

(defun my-dash-pad (s width)
  "把字符串 S 右填充到宽度 WIDTH (用空格)."
  (concat s (make-string (max 0 (- width (string-width s))) ?\s)))

(defun my-dash-two-col (left-lines right-lines)
  "把左右两栏行列表按列宽对齐拼接成单行列表."
  (let* ((n (max (length left-lines) (length right-lines)))
         (l-pad (append left-lines (make-list (- n (length left-lines)) "")))
         (r-pad (append right-lines (make-list (- n (length right-lines)) "")))
         out)
    (dotimes (i n)
      (push (concat (my-dash-pad (nth i l-pad) my-dash-col-width)
                    "  "
                    (my-dash-pad (nth i r-pad) my-dash-col-width)) out))
    (reverse out)))

(defun my-dash-render ()
  "渲染整个 Dashboard 到当前 buffer."
  (let* ((agenda (my-dash-agenda-summary))
         (todo (my-dash-todo-summary))
         (recents (my-dash-recents-lines))
         (projects (my-dash-projects-lines)))
    (erase-buffer)
    ;; 垂直偏移 (顶部空行)
    (dotimes (_ my-dash-v-offset) (insert "\n"))
    ;; EMACS 标题
    (insert (propertize "EMACS" 'face '(:height 2.5 :weight bold :foreground "#61afef")))
    (insert "\n\n")
    ;; 顶部按钮行
    (my-dash-insert-top-buttons)
    (insert "\n\n")
    ;; 第一行 = Today's Agenda | TODO (含 Open Agenda / Show all 按钮行)
    (let ((row1 (my-dash-two-col
                 (my-dash-block "Today's Agenda"
                                (append agenda '("→ Open Agenda")))
                 (my-dash-block "TODO" todo))))
      (dolist (l row1) (insert l "\n")))
    (insert "\n")
    ;; 第二行 = Recent Files | Projects
    (let ((row2 (my-dash-two-col
                 (my-dash-block "Recent Files" recents)
                 (my-dash-block "Projects" projects))))
      (dolist (l row2) (insert l "\n")))
    (insert "\n\n")
    (insert (propertize (format "Happy hacking! · Emacs %s" emacs-version)
                        'face '(:foreground "#aaaaaa" :slant italic)))
    (insert "\n")))

(defun my-dash-insert-button (label action &optional help face)
  "插入一个可点击按钮 (make-text-button, 最可靠)."
  (let ((start (point)))
    (insert (propertize label 'face (or face '(:foreground "#7aa2f7"))))
    (make-text-button start (point)
                      'action (lambda (_) (interactive) (apply action nil))
                      'follow-link t
                      'mouse-face 'highlight
                      'help-echo help)))

(defun my-dash-insert-top-buttons ()
  "插入顶部按钮行 (Agenda/Inbox/Capture/Mail)."
  (let ((buttons '(("📅" "Agenda" "今日日程 + 待办" (org-agenda nil "n"))
                   ("📥" "Inbox" "打开收件箱 inbox.org" (find-file "~/org/inbox.org"))
                   ("✚" "Capture" "快速捕获 (C-c c)" (org-capture))
                   ("✉" "Mail" "收邮件 (Gnus)" (gnus)))))
    (dolist (b buttons)
      (my-dash-insert-button (concat (nth 0 b) " " (nth 1 b)) (nth 3 b) (nth 2 b))
      (insert "   "))
    (insert "\n")))

;; ---------- 居中 ----------

(defun my-dash--center-h (w)
  "把整个 Dashboard 内容按窗口宽度 W 水平居中 (整体左缩进, 非逐行)."
  (save-excursion
    (goto-char (point-min))
    ;; 找最宽行 (内容宽度 = 两栏宽 + 间隔)
    (let ((maxw 0))
      (cl-loop while (not (eobp))
               do (let ((len (length (buffer-substring-no-properties (point) (line-end-position)))))
                    (setq maxw (max maxw len)))
               (forward-line 1))
      (when (< maxw w)
        (let ((pad (make-string (max 0 (/ (- w maxw) 2)) ?\s)))
          (goto-char (point-min))
          (cl-loop while (not (eobp))
                   do (insert pad)
                   (forward-line 1)))))))

(defun my-dashboard ()
  "打开/刷新 Dashboard."
  (interactive)
  (let ((buf (get-buffer-create my-dash-buffer-name)))
    (with-current-buffer buf
      (setq buffer-read-only nil)
      (my-dash-render)
      ;; 按 frame 宽度整体居中
      (my-dash--center-h (frame-width))
      (special-mode)
      ;; 首页隐藏视觉元素 (buffer-local, 不破坏正常操作)
      (display-line-numbers-mode -1)
      (setq-local cursor-type nil)
      (setq-local mode-line-format nil)
      ;; 忽略触控板横向三击事件 (避免 "undefined" 报错)
      (local-set-key (kbd "<triple-wheel-left>") #'ignore)
      (local-set-key (kbd "<triple-wheel-right>") #'ignore)
      (local-set-key (kbd "<double-wheel-left>") #'ignore)
      (local-set-key (kbd "<double-wheel-right>") #'ignore)
      (setq buffer-read-only t)
      (setq-local revert-buffer-function
                  (lambda (&rest _) (my-dashboard))))
    (switch-to-buffer buf)))

;; ---------- 启动显示 ----------
(setq initial-buffer-choice #'my-dashboard)

(provide 'init-dashboard)
;;; init-dashboard.el ends here
