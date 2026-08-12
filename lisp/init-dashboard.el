;;; init-dashboard.el --- 自写 Dashboard 主页 (双栏 home screen) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; 替代 emacs-dashboard 包, 自写一个双栏 home screen (用户 mockup 2026-08):
;;
;;                  EMACS
;;
;;        [Agenda] [Inbox] [Capture] [Mail]
;;
;;  ┌──────────────────┐  ┌──────────────────┐
;;  │ Today's Agenda   │  │ TODO             │
;;  └──────────────────┘  └──────────────────┘
;;  ┌──────────────────┐  ┌──────────────────┐
;;  │ Recent Files     │  │ Projects         │
;;  └──────────────────┘  └──────────────────┘
;;
;; 数据源:
;;   - Today's Agenda: org-agenda-list (真实生成, 含今天 scheduled/deadline)
;;   - TODO:            org-todo-list "NEXT|TODO|DOING|HOLD"
;;   - Recent Files:    recentf-list
;;   - Projects:        projectile-known-projects
;;
;; 设计: 用固定列宽把左右两栏文本对齐拼接, 单个 buffer 内实现双栏。
;;       按钮用 make-text-button (最可靠), 鼠标可点 + 键盘直达。

;;; Code:

(defgroup my-dashboard nil
  "自写 Dashboard 主页."
  :group 'emacs)

(defcustom my-dash-buffer-name "*My Dashboard*"
  "Dashboard buffer 名."
  :type 'string :group 'my-dashboard)

;; 列宽 (字符). 两栏各占一半减间隙. 大屏可调大.
(defcustom my-dash-col-width 48
  "每栏内容列宽 (字符数). 双栏共约 2*col-width."
  :type 'integer :group 'my-dashboard)

(defcustom my-dash-show-agenda t
  "显示 Today's Agenda 块."
  :type 'boolean :group 'my-dashboard)

;; ---------- 数据提取 ----------

(defun my-dash-agenda-lines ()
  "返回 Today's Agenda 的纯文本行列表 (真实调用 org-agenda-list)."
  (let ((buf (get-buffer-create " *my-dash-agenda*"))
        lines)
    (with-current-buffer buf
      (erase-buffer)
      (condition-case nil
          (org-agenda-list)  ; 无参 = 今天开始
        (error nil))
      ;; 提取: 跳过表头 (第一行是 Week-agenda), 取含今天日期的行 + 之后的条目行
      (setq lines
            (split-string (buffer-substring-no-properties (point-min) (point-max))
                          "\n" t)))
    (kill-buffer buf)
    ;; 清理: 去掉空行和标题行, 保留实际条目 (含 Scheduled/DONE 的)
    (let ((out '()))
      (dolist (l lines)
        (when (and (not (string-match-p "^[A-Za-z]+ *[0-9]" l))   ; 去日期表头
                   (not (string-prefix-p "Week-agenda" (string-trim l)))
                   (not (string-prefix-p "Global list" (string-trim l)))
                   (not (string-prefix-p "Press" (string-trim l)))
                   (string-match-p "\\S-" l))
          (push (string-trim (replace-regexp-in-string "\\s+" " " l)) out)))
      (reverse out))))

(defun my-dash-todo-lines ()
  "返回 TODO 列表的纯文本行 (org-todo-list NEXT|TODO|DOING|HOLD)."
  (let ((buf (get-buffer-create " *my-dash-todo*"))
        lines)
    (with-current-buffer buf
      (erase-buffer)
      (condition-case nil
          (org-todo-list "NEXT|TODO|DOING|HOLD")
        (error nil))
      (setq lines
            (split-string (buffer-substring-no-properties (point-min) (point-max))
                          "\n" t)))
    (kill-buffer buf)
    (let ((out '()))
      (dolist (l lines)
        (when (and (string-match-p "TODO\\|NEXT\\|DOING\\|HOLD" l)
                   (string-match-p ":" l)  ; 有文件前缀冒号
                   (not (string-prefix-p "Global list" (string-trim l)))
                   (not (string-prefix-p "Press" (string-trim l)))
                   (not (string-prefix-p "(" (string-trim l)))
                   (string-match-p "\\S-" l))
          (push (string-trim (replace-regexp-in-string "\\s+" " " l)) out)))
      (reverse out))))

(defun my-dash-recents-lines (&optional n)
  "返回最近文件列表 (recentf-list), 最多 N 个 (默认 8)."
  (let ((n (or n 8)))
    (cl-subseq recentf-list 0 (min n (length recentf-list)))))

(defun my-dash-projects-lines (&optional n)
  "返回已知项目列表 (projectile-known-projects), 最多 N 个 (默认 8)."
  (when (fboundp 'projectile-known-projects)
    (let ((n (or n 8))
          (ps (ignore-errors (projectile-known-projects))))
      (cl-subseq ps 0 (min n (length ps))))))

;; ---------- 渲染 ----------

(defun my-dash-block (title lines &optional icon)
  "渲染一个内容块为多行字符串 (带标题栏 + 边框). 返回字符串列表.
顺序: 顶边框 → 标题 → 内容 → 底边框. 固定 10 行内容区 (不足补空, 两栏等高)."
  (let* ((w my-dash-col-width)
         (fill (lambda (s)
                 (let ((ts (truncate-string-to-width (or s "") (- w 4) nil nil t)))
                   (concat "│ " ts
                           (make-string (max 0 (- (- w 4) (string-width ts))) ?\s)
                           " │"))))
         (border (concat "┌" (make-string (- w 2) ?─) "┐"))
         (bottom (concat "└" (make-string (- w 2) ?─) "┘"))
         (title-str (funcall fill title)))
    (append (list border title-str)
            (mapcar fill (append (cl-subseq lines 0 (min (length lines) 10))
                                 (make-list (max 0 (- 10 (min (length lines) 10))) "")))
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
  (let* ((agenda (my-dash-agenda-lines))
         (todo (my-dash-todo-lines))
         (recents (my-dash-recents-lines 8))
         (projects (my-dash-projects-lines 8)))
    (erase-buffer)
    ;; EMACS 标题 (ASCII banner)
    (insert (propertize "EMACS" 'face '(:height 2.5 :weight bold :foreground "#61afef")))
    (insert "\n\n")
    ;; 顶部按钮行
    (my-dash-insert-top-buttons)
    (insert "\n\n")
    ;; 双栏: 第一行 = Agenda | TODO
    (let ((row1 (my-dash-two-col
                 (my-dash-block "Today's Agenda" agenda "📅")
                 (my-dash-block "TODO" todo "✅"))))
      (dolist (l row1) (insert l "\n")))
    (insert "\n")
    ;; 第二行 = Recent Files | Projects
    (let ((row2 (my-dash-two-col
                 (my-dash-block "Recent Files"
                                (mapcar (lambda (p) (file-name-nondirectory
                                                     (directory-file-name p))) recents)
                                "🕘")
                 (my-dash-block "Projects"
                                (mapcar (lambda (p) (file-name-nondirectory
                                                     (directory-file-name p))) projects)
                                "📁"))))
      (dolist (l row2) (insert l "\n")))
    (insert "\n")
    (insert (propertize (format "Happy hacking! · Emacs %s" emacs-version)
                        'face '(:foreground "#aaaaaa" :slant italic)))
    (insert "\n")))

(defun my-dash-insert-top-buttons ()
  "插入顶部按钮行 (Agenda/Inbox/Capture/Mail)."
  (let ((buttons '(("📅" "Agenda" "今日日程 + 待办" (org-agenda nil "n"))
                   ("📥" "Inbox" "打开收件箱 inbox.org" (find-file "~/org/inbox.org"))
                   ("✚" "Capture" "快速捕获 (C-c c)" (org-capture))
                   ("✉" "Mail" "收邮件 (Gnus)" (gnus)))))
    (dolist (b buttons)
      (let ((label (concat (nth 0 b) " " (nth 1 b))))
        (my-dash-insert-button label (nth 3 b) (nth 2 b)))
      (insert "   "))
    (insert "\n")))

(defun my-dash-insert-button (label action &optional help)
  "插入一个可点击按钮 (make-text-button, 最可靠)."
  (let ((start (point)))
    (insert (propertize label 'face '(:foreground "#7aa2f7")))
    (make-text-button start (point)
                      'action (lambda (_) (interactive) (apply action nil))
                      'follow-link t
                      'mouse-face 'highlight
                      'help-echo help)))

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
      (setq buffer-read-only t)
      (setq-local revert-buffer-function
                  (lambda (&rest _) (my-dashboard))))
    (switch-to-buffer buf)))

;; ---------- 启动显示 ----------
(setq initial-buffer-choice #'my-dashboard)

(provide 'init-dashboard)
;;; init-dashboard.el ends here
