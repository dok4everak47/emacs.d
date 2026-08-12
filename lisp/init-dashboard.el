;;; init-dashboard.el --- 自写 Dashboard 主页 (双栏 home screen) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; 替代 emacs-dashboard 包, 自写双栏 home screen (2026-08 重构)。
;; 设计原则: Dashboard 是"个人工作台首页", 只做概览不堆信息:
;;   - Today's Agenda: 只显示摘要 (带时间条目 + Habits ×N), 完整看 C-c a
;;   - TODO:           只显示最重要 5 条
;;   - Recent Files:   5-6 条, 过滤临时文件
;;   - Projects:       去重, 最多 5 个
;;   - Quick Actions:  一行常用操作 (填充利用率)
;;   - 隐藏行号/cursor/mode-line (buffer-local, 不破坏正常操作)
;;
;; 数据源:
;;   - Today's Agenda: org-agenda-list (真实生成, 只取摘要)
;;   - TODO:            org-todo-list "NEXT|TODO|DOING|HOLD" (取前 5)
;;   - Recent Files:    recentf-list (过滤临时/不存在)
;;   - Projects:        projectile-known-projects (按显示名去重)
;;
;; 布局 (用户 mockup):
;;                  EMACS
;;        [Agenda] [Inbox] [Capture] [Mail]
;;   ┌────────────┐ ┌────────────┐
;;   │ Today's    │ │ TODO       │
;;   │ Agenda     │ │            │
;;   └────────────┘ └────────────┘
;;   ┌────────────┐ ┌────────────┐
;;   │ Recent     │ │ Projects   │
;;   │ Files      │ │            │
;;   └────────────┘ └────────────┘
;;        [A] Agenda [C] Capture [I] Inbox [P] Projects [M] Mail
;;
;; 按钮用 make-text-button (最可靠), 鼠标可点 + 键盘直达。

;;; Code:

(defgroup my-dashboard nil
  "自写 Dashboard 主页."
  :group 'emacs)

(defcustom my-dash-buffer-name "*My Dashboard*"
  "Dashboard buffer 名."
  :type 'string :group 'my-dashboard)

(defcustom my-dash-col-width 46
  "每栏内容列宽 (字符数). 双栏共约 2*col-width."
  :type 'integer :group 'my-dashboard)

(defcustom my-dash-todo-count 5
  "TODO 区最多显示条数."
  :type 'integer :group 'my-dashboard)

(defcustom my-dash-recents-count 6
  "Recent Files 最多显示条数."
  :type 'integer :group 'my-dashboard)

(defcustom my-dash-projects-count 5
  "Projects 最多显示条数."
  :type 'integer :group 'my-dashboard)

;; ---------- 数据提取 ----------

(defun my-dash-agenda-summary ()
  "返回 Today's Agenda 摘要 (字符串行列表).
只提取带具体时刻的非习惯条目 + 习惯计数, 不复制完整 agenda."
  (let ((buf (get-buffer-create " *my-dash-agenda*"))
        lines (habits 0) (out '()))
    (with-current-buffer buf
      (erase-buffer)
      (condition-case nil (org-agenda-list) (error nil))
      (setq lines (split-string
                   (buffer-substring-no-properties (point-min) (point-max))
                   "\n" t)))
    (kill-buffer buf)
    (dolist (l lines)
      (cond
       ;; 习惯条目 → 计数 (Sched. 6x / Scheduled + :habit:)
       ((string-match "habit" l) (cl-incf habits))
       ;; 非习惯条目, 且带具体时刻 HH:MM → 摘要显示
       ((and (string-match "^[[:space:]]*[A-Za-z0-9_-]+:" l)
             (string-match "[0-9][0-9]:[0-9][0-9]" l))
        (push (string-trim (replace-regexp-in-string "[[:space:]]+" " " l)) out))))
    ;; 习惯计数放最前
    (let ((result '()))
      (when (> habits 0)
        (push (format "Habits × %d" habits) result))
      (append result (reverse out)))))

(defun my-dash-todo-summary ()
  "返回 TODO 摘要 (最多 my-dash-todo-count 条, 格式 '状态 标题')."
  (let ((buf (get-buffer-create " *my-dash-todo*"))
        lines (out '()))
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
          (let* ((st (match-string 1 trimmed))
                 (ti (match-string 2 trimmed))
                 ;; 去掉行尾所有 tag 部分: ":project:" / ":project::" / ":project"
                 (ti (replace-regexp-in-string "[[:space:]]*:[^[:space:]:]+:+[[:space:]]*$" "" ti))
                 (ti (string-trim ti)))
            (when (not (string-empty-p ti))
              (push (format "%s %s" st ti) out))))))
    (reverse (cl-subseq (reverse out) 0 (min my-dash-todo-count (length out))))))

(defun my-dash-recents-lines ()
  "返回最近文件 basename 列表 (过滤不存在/临时文件), 最多 my-dash-recents-count 条."
  (let ((out '()))
    (dolist (f recentf-list)
      (when (and (< (length out) my-dash-recents-count)
                 (file-exists-p f)
                 (not (string-match "/tmp/" f))        ; 临时目录
                 (not (string-match "/\\.cache/" f))
                 (not (string-match "appt\\.txt" f)))  ; 临时文件
        (push (file-name-nondirectory (directory-file-name f)) out)))
    (reverse out)))

(defun my-dash-projects-lines ()
  "返回项目 basename 列表 (折叠空格后去重), 最多 my-dash-projects-count 个."
  (when (fboundp 'projectile-known-projects)
    (let ((out '()) seen)
      (dolist (p (ignore-errors (projectile-known-projects)))
        (let* ((name (file-name-nondirectory (directory-file-name p)))
               ;; 折叠连续空格 (如 "Lisp  tutorial" → "Lisp tutorial"), 再按折叠名去重
               (key (replace-regexp-in-string "[[:space:]]+" " " name)))
          (when (and (< (length out) my-dash-projects-count)
                     (not (member key seen)))
            (push name out)
            (push key seen))))
      (reverse out))))

;; ---------- 渲染 ----------

(defun my-dash-block (title lines)
  "渲染一个内容块为多行字符串列表 (顶边框 → 标题 → 内容 → 底边框)."
  (let* ((w my-dash-col-width)
         (fill (lambda (s)
                 (let ((ts (truncate-string-to-width (or s "") (- w 4) nil nil t)))
                   (concat "│ " ts
                           (make-string (max 0 (- (- w 4) (string-width ts))) ?\s)
                           " │"))))
         (border (concat "┌" (make-string (- w 2) ?─) "┐"))
         (bottom (concat "└" (make-string (- w 2) ?─) "┘")))
    (append (list border (funcall fill title))
            (mapcar fill lines)
            (list bottom))))

(defun my-dash-pad (s width)
  "把字符串 S 右填充到宽度 WIDTH (用空格)."
  (concat s (make-string (max 0 (- width (string-width s))) ?\s)))

(defun my-dash-two-col (left-lines right-lines)
  "把左右两栏行列表按列宽对齐拼接成单行列表. 两栏各自等高 (补空行对齐底边)."
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
    ;; EMACS 标题 (ASCII banner)
    (insert (propertize "EMACS" 'face '(:height 2.5 :weight bold :foreground "#61afef")))
    (insert "\n\n")
    ;; 顶部按钮行
    (my-dash-insert-top-buttons)
    (insert "\n\n")
    ;; 第一行 = Today's Agenda | TODO
    (let ((row1 (my-dash-two-col
                 (my-dash-block "Today's Agenda" agenda)
                 (my-dash-block "TODO" todo))))
      (dolist (l row1) (insert l "\n")))
    (insert "\n")
    ;; 第二行 = Recent Files | Projects
    (let ((row2 (my-dash-two-col
                 (my-dash-block "Recent Files" recents)
                 (my-dash-block "Projects" projects))))
      (dolist (l row2) (insert l "\n")))
    (insert "\n")
    ;; Quick Actions 行 (填充利用率, 不堆键位)
    (my-dash-insert-quick-actions)
    (insert "\n")
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

(defun my-dash-insert-quick-actions ()
  "插入 Quick Actions 行 (常用操作, 不堆键位)."
  (let ((actions '(("Agenda" (org-agenda nil "n") "今日日程 + 待办")
                   ("Capture" (org-capture) "快速捕获")
                   ("Inbox" (find-file "~/org/inbox.org") "打开收件箱")
                   ("Projects" (find-file "~/org/projects.org") "打开项目树")
                   ("Mail" (gnus) "收邮件")
                   ("Recent" (consult-recent-file) "最近文件"))))
    (let ((start (point)))
      (insert (propertize "Quick Actions  " 'face '(:foreground "#98c379" :weight bold))))
    (dolist (a actions)
      (my-dash-insert-button (nth 0 a) (nth 1 a) (nth 2 a) '(:foreground "#56b6c2"))
      (insert "  "))
    (insert "\n")))

;; ---------- 入口 & 居中 ----------

(defun my-dash--recenter (w)
  "把渲染好的 Dashboard buffer 水平居中 (W 是窗口宽度)."
  (save-excursion
    (goto-char (point-min))
    (cl-loop while (not (eobp))
             do (let ((line-len (length (buffer-substring-no-properties (point) (line-end-position)))))
                  (when (> w line-len)
                    (insert (make-string (max 0 (/ (- w line-len) 2)) ?\s)))
                  (forward-line 1)))))

(defun my-dashboard ()
  "打开/刷新 Dashboard."
  (interactive)
  (let ((buf (get-buffer-create my-dash-buffer-name)))
    (with-current-buffer buf
      (setq buffer-read-only nil)
      (my-dash-render)
      ;; 水平居中
      (let ((win (get-buffer-window buf t)))
        (my-dash--recenter (if win (window-width win) (frame-width))))
      (special-mode)
      ;; 首页隐藏视觉元素 (buffer-local, 不破坏正常操作)
      (display-line-numbers-mode -1)
      (setq-local cursor-type nil)
      (setq-local mode-line-format nil)
      (setq buffer-read-only t)
      (setq-local revert-buffer-function
                  (lambda (&rest _) (my-dashboard))))
    (switch-to-buffer buf)))

;; ---------- 启动显示 ----------
(setq initial-buffer-choice #'my-dashboard)

(provide 'init-dashboard)
;;; init-dashboard.el ends here
