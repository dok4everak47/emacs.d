;;; -*- lexical-binding: t -*-
;;; custom.el — Customize UI 的自动写入区 (Emacs 自动维护, 见文件头注释)
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))
;;; init.el — Emacs 邮件发送配置 (多账号: Gmail + 126)
;;;
;;; ================= 邮箱账号 =================
;;; 真实邮箱地址在 accounts.el (已 gitignore, 不入库);
;;; 公开版本用占位符, 本机加载 accounts.el 后自动覆盖。
(defvar my-gmail-address "your-gmail@gmail.com")
(defvar my-mail126-address "your-126@126.com")
(when (file-exists-p (expand-file-name "accounts.el" user-emacs-directory))
  (load (expand-file-name "accounts.el" user-emacs-directory)))
;;;
;;; 网络拓扑:
;;;   Gmail: Emacs → 127.0.0.1:1465 (socat 隧道, launchd 常驻)
;;;          → ClashX SOCKS 127.0.0.1:7890 → smtp.gmail.com:465 (TLS)
;;;   126:   Emacs → smtp.126.com:465 (国内直连, 无需代理)
;;;
;;; 钥匙串条目 (应用专用密码/授权码):
;;;   service=smtp.gmail.com  account=<gmail>
;;;   service=smtp.126.com    account=<126>

(require 'smtpmail)

;; --- 收件人补全: ecomplete (历史邮箱自动积累 + TAB 补全) ---
;; 发送邮件时自动记录收件人; 写 To/Cc/Bcc 时输入几个字母按 TAB 弹出候选。
(setq message-mail-alias-type 'ecomplete
      message-expand-name-standard-ui t)   ; 必须开新 UI, 否则 TAB 只走 abbrev
(require 'ecomplete)
(ecomplete-setup)

;; 确保 126 已发送归档文件存在 (避免发送时 gnus 询问"创建吗")
(unless (file-exists-p "~/Mail/126-Sent.mbox")
  (write-region "" nil (expand-file-name "~/Mail/126-Sent.mbox")))

;; --- 发件人身份 (默认 Gmail) ---
(setq user-full-name "Jinzhou Liang"
      user-mail-address my-gmail-address)

;; --- SMTP 发送 (默认 Gmail) ---
(setq message-send-mail-function 'smtpmail-send-it
      smtpmail-smtp-server "127.0.0.1"
      smtpmail-smtp-service 1465
      smtpmail-stream-type 'ssl
      smtpmail-smtp-user my-gmail-address
      smtpmail-debug-info t)          ; 出错时看 *Messages* 里的 SMTP 会话

;; ================= 多账号支持 =================
;; 用法: M-x my-compose-gmail / my-compose-mail126 新建邮件,
;;       发送时 (message-send-hook) 按 buffer 的账号切换 SMTP 参数。

(defvar-local my-mail-account 'gmail
  "当前邮件 buffer 使用的账号: gmail 或 mail126.")

(defun my-mail-remove-header (name)
  "在 header 区删除名为 NAME 的头 (不带冒号; message-remove-header 会自己加)."
  (save-restriction
    (message-narrow-to-headers)
    (message-remove-header name)))

(defun my-mail-fix-from ()
  "重写当前邮件 buffer 的 From 头为当前账号 (my-mail-account)."
  (when (eq major-mode 'message-mode)
    (my-mail-remove-header "From")
    (message-add-header
     (format "From: %s <%s>\n" user-full-name user-mail-address))))

(defun my-mail-account-setup ()
  "根据 buffer 的 my-mail-account 设置 SMTP 参数并修正 From (发送前调用)."
  (pcase my-mail-account
    ('gmail
     (setq smtpmail-smtp-server "127.0.0.1"
           smtpmail-smtp-service 1465
           smtpmail-smtp-user my-gmail-address
           user-mail-address my-gmail-address
           user-full-name "Jinzhou Liang")
     ;; Gmail 服务器自动保存已发送到 Sent Mail; 清掉可能残留的 Fcc
     (my-mail-remove-header "Fcc"))
    ('mail126
     (setq smtpmail-smtp-server "smtp.126.com"
           smtpmail-smtp-service 465
           smtpmail-smtp-user my-mail126-address
           user-mail-address my-mail126-address
           user-full-name "Jinzhou Liang")
     ;; 126 SMTP 不自动归档, Fcc 到本地 mbox 作为已发送
     (unless (message-field-value "fcc" t)
       (message-add-header "Fcc: ~/Mail/126-Sent.mbox\n"))))
  ;; From 头在 compose 时已按旧账号生成, 这里强制对齐当前账号
  (my-mail-fix-from))
(add-hook 'message-send-hook #'my-mail-account-setup)

(defun my-compose-gmail ()
  "写新邮件, 用 Gmail 账号发送."
  (interactive)
  (compose-mail)
  (setq my-mail-account 'gmail)
  (my-mail-account-setup))

(defun my-compose-mail126 ()
  "写新邮件, 用 126 账号发送."
  (interactive)
  (compose-mail)
  (setq my-mail-account 'mail126)
  (my-mail-account-setup))

(defun my-mail-account-menu ()
  "弹出账号选择菜单, 返回 'gmail 或 'mail126; 取消返回 nil."
  (x-popup-menu
   t '("选择发送账号"
       ("Accounts"
        ((concat "Gmail — " my-gmail-address) . gmail)
        ((concat "126 — " my-mail126-address) . mail126)))))

(defun my-compose-mail ()
  "写新邮件, 弹出账号列表选择发送账号."
  (interactive)
  (let ((acct (my-mail-account-menu)))
    (when acct
      (compose-mail)
      (setq my-mail-account acct)
      (my-mail-account-setup)
      (message "邮件账号: %s → 发送人 %s" acct user-mail-address))))

(global-set-key (kbd "C-c m m") #'my-compose-mail)      ; 写邮件(弹出选择账号)
(global-set-key (kbd "C-c m g") #'my-compose-gmail)    ; Gmail 写邮件(直达)
(global-set-key (kbd "C-c m 1") #'my-compose-mail126)  ; 126 写邮件(直达)

(defun my-mail-switch-account ()
  "切换当前邮件 buffer 的发送账号 (写了一半想换账号时用)."
  (interactive)
  (let ((acct (my-mail-account-menu)))
    (when acct
      (setq my-mail-account acct)
      (my-mail-account-setup)
      (message "已切换账号: %s → 发送人 %s" acct user-mail-address))))
(require 'message)
(define-key message-mode-map (kbd "C-c m s") #'my-mail-switch-account)

;; ================= 定时发送 =================
;; C-c m t → 提示输入发送时间, 到点自动发送当前邮件
;; 时间格式: "19:00" 今天19点 / "09:30+1" 明天9点半 / "8h" 8小时后
(defvar my-mail-timer nil "当前邮件的定时发送 timer.")
(defvar my-mail-timer-string nil "定时发送时间的人类可读描述.")

(defun my-mail-parse-time (s)
  "解析定时时间 S: '19:00' 今天 / '09:30+1' 明天 / '8h' 8小时后.
返回绝对时间 (encode-time 兼容), 解析失败返回 nil."
  (cond
   ((string-match "^\\([0-9]\\{1,2\\}\\):\\([0-9]\\{2\\}\\)\\(\\+[0-9]+\\)?$" s)
    (let* ((hh (string-to-number (match-string 1 s)))
           (mm (string-to-number (match-string 2 s)))
           (days (if (match-string 3 s)
                     (string-to-number (substring (match-string 3 s) 1))
                   0))
           (base (decode-time (current-time))))
      (setf (nth 2 base) hh (nth 1 base) mm (nth 0 base) 0)
      (when (and (= days 0)
                 (time-less-p (apply 'encode-time base) (current-time)))
        (setf (nth 3 base) (+ (nth 3 base) 1)))  ; 时间已过→明天
      (setf (nth 3 base) (+ (nth 3 base) days))
      (apply 'encode-time base)))
   ((string-match "^\\([0-9]+\\)h$" s)
    (time-add (current-time) (* 3600 (string-to-number (match-string 1 s)))))
   (t nil)))

(defun my-mail-send-at (time-str)
  "定时发送当前邮件: 到 TIME-STR 自动 message-send.
用法示例: 19:00 (今天19点) / 09:30+1 (明天9点半) / 8h (8小时后)."
  (interactive "s定时发送时间 (例 19:00 / 09:30+1 / 8h): ")
  (unless (eq major-mode 'message-mode)
    (user-error "当前不是邮件 buffer"))
  (let ((target (my-mail-parse-time time-str)))
    (unless target (user-error "时间格式不对: 用 19:00 / 09:30+1 / 8h"))
    (when my-mail-timer (cancel-timer my-mail-timer))
    (setq my-mail-timer
          (run-at-time target nil
                       (lambda (buf)
                         (if (buffer-live-p buf)
                             (with-current-buffer buf
                               (when (and (eq major-mode 'message-mode)
                                          (message-field-value "to"))
                                 (message "定时发送: %s" (buffer-name buf))
                                 (message-send)))
                           (message "定时发送失败: 邮件 buffer 已被关闭")))
                       (current-buffer))
          my-mail-timer-string
          (format-time-string "%m-%d %H:%M" target))
    (message "已设定 %s 定时发送 (%s)" my-mail-timer-string time-str)))

(define-key message-mode-map (kbd "C-c m t") #'my-mail-send-at)

;; ================= 附件: 人性化方案 =================
;; 1) C-c C-a → macOS 原生文件选择对话框 (不再手输路径)
;; 2) 从 Finder 拖文件到邮件窗口 → 自动附加
;; 旧方式 M-x mml-attach-file 仍可用 (手输路径/TAB 补全)

(defun my-mail-attach-file ()
  "用 macOS 原生文件对话框选择附件."
  (interactive)
  (let ((file (x-file-dialog "选择附件" "~/" nil t)))
    (if (and file (file-exists-p file))
        (mml-attach-file file)
      (message "已取消附加"))))

(defun my-dnd-attach (uri _action)
  "从 Finder 拖文件到邮件 buffer 时自动附加为附件."
  (when (and (derived-mode-p 'message-mode)
             (string-match "\\`file://" uri))
    (mml-attach-file
     (url-unhex-string (url-filename (url-generic-parse-url uri))))
    t))
(require 'dnd)
(push '("^file://" . my-dnd-attach) dnd-protocol-alist)
(define-key message-mode-map (kbd "C-c C-a") #'my-mail-attach-file)

;; ================= 邮件快捷面板 =================
;; C-c m p 打开面板: 写邮件/账号选择/帮助集中一页, 数字键或鼠标点选

(defvar my-mail-panel-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map "1" #'my-compose-mail)
    (define-key map "2" #'my-compose-gmail)
    (define-key map "3" #'my-compose-mail126)
    (define-key map "4" #'my-mail-help)
    (define-key map "g" #'my-mail-panel)
    map))

(define-derived-mode my-mail-panel-mode special-mode "邮件面板"
  "邮件快捷操作面板."
  (setq buffer-read-only t))

(defun my-mail-panel-render ()
  "渲染邮件面板内容."
  (interactive)
  (let ((inhibit-read-only t))
    (erase-buffer)
    (goto-char (point-min))
    (insert (propertize "╔══════════════════════════════════════╗\n"
                        'face 'bold))
    (insert (propertize "║          📧 邮件快捷操作            ║\n" 'face 'bold))
    (insert (propertize "╚══════════════════════════════════════╝\n\n"
                        'face 'bold))
    (my-mail-panel-button "1" "✉ 写新邮件（弹出账号菜单）" #'my-compose-mail)
    (my-mail-panel-button "2" "✉ 写 Gmail 邮件" #'my-compose-gmail)
    (my-mail-panel-button "3" "✉ 写 126 邮件" #'my-compose-mail126)
    (my-mail-panel-button "4" "? 快捷键帮助" #'my-mail-help)
    (insert "\n──────────────────────────────────────\n")
    (insert "常用键:  C-c C-c 发送   C-c C-a 附件\n")
    (insert "         C-c m s 切账号   C-c m p 回到面板\n")
    (insert "──────────────────────────────────────\n\n")
    (insert "按数字键 [1-4] 或点击上方按钮;  q 关闭面板。\n")))

(defun my-mail-panel-button (key label cmd)
  "插入面板按钮: KEY 数字键, LABEL 显示文本, CMD 点击动作."
  (let ((start (point)))
    (insert (format "[%s] %s\n" key label))
    (make-text-button start (1- (point))
                      'action (lambda (_) (call-interactively cmd))
                      'follow-link t
                      'help-echo (format "点击: %s" label))))

(defun my-mail-panel ()
  "打开邮件快捷操作面板."
  (interactive)
  (switch-to-buffer (get-buffer-create "*邮件面板*"))
  (my-mail-panel-mode)
  (my-mail-panel-render)
  (goto-char (point-min)))

(defun my-mail-help ()
  "显示邮件快捷键帮助."
  (interactive)
  (let ((buf (get-buffer-create "*邮件帮助*")))
    (switch-to-buffer buf)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert "📧 邮件快捷键速查\n")
      (insert "═══════════════════════════════\n\n")
      (insert "写邮件\n")
      (insert "  C-c m p    打开邮件面板\n")
      (insert "  C-c m m    写新邮件(弹菜单选账号)\n")
      (insert "  C-c m g    写 Gmail 邮件\n")
      (insert "  C-c m 1    写 126 邮件\n")
      (insert "  C-c m s    邮件中切换账号\n\n")
      (insert "编辑\n")
      (insert "  C-c C-a    添加附件(文件对话框)\n")
      (insert "  C-c C-c    发送\n")
      (insert "  C-c C-d    丢弃草稿\n\n")
      (insert "账号\n")
      (insert (format "  Gmail: %s (经代理隧道)\n" my-gmail-address))
      (insert (format "  126:   %s (国内直连)\n" my-mail126-address)))
    (help-mode)))

(global-set-key (kbd "C-c m p") #'my-mail-panel)

;; ================= 密码注入 =================
;; smtpmail 用 smtpmail-smtp-server 作为 auth-source 的 :host 查密码,
;; Gmail 场景 host 是本地隧道 127.0.0.1, 必须注入真实密码条目。
;; (内置 macos-keychain-generic 后端的 generic 字段映射与本机条目不符,
;;  且部分构建没有该后端, 直接用 security CLI 最可控)
(defun my-auth-source-host-match (host regexp)
  "HOST 可能是字符串或列表 (Gnus nnimap 传 server 名+地址的列表), 任一匹配即真."
  (let ((hosts (if (listp host) host (list host))))
    (seq-some (lambda (h) (and (stringp h) (string-match regexp h))) hosts)))

(defun my-auth-source-inject (orig-fn &rest args)
  "从 macOS 钥匙串注入 SMTP/IMAP 密码 (Gmail 隧道 / 126 直连)."
  (let ((host (plist-get args :host)))
    (cond
     ((my-auth-source-host-match host "127\\.0\\.0\\.1")
      (my-auth-source-keychain-entry orig-fn args host
                                     my-gmail-address "smtp.gmail.com"))
     ((my-auth-source-host-match host "smtp\\.126\\.com")
      (my-auth-source-keychain-entry orig-fn args host
                                     my-mail126-address "smtp.126.com"))
     ((my-auth-source-host-match host "imap\\.126\\.com")
      (my-auth-source-keychain-entry orig-fn args host
                                     my-mail126-address "imap.126.com"))
     (t (apply orig-fn args)))))

(defun my-auth-source-keychain-entry (orig-fn args host account service)
  "从钥匙串读 service 条目的密码并构造 auth-source 条目; 失败则回退原逻辑."
  (let ((pass (string-trim
               (shell-command-to-string
                (format "security find-generic-password -a '%s' -s '%s' -w 2>/dev/null"
                        account service)))))
    (if (string-empty-p pass)
        (apply orig-fn args)
      (list (list :host host
                  :port (plist-get args :port)
                  :user (plist-get args :user)
                  :secret pass)))))
(advice-add 'auth-source-search :around #'my-auth-source-inject)

;; ================= Gmail 隧道 TLS =================
;; Emacs 30 的 smtpmail 直接调 open-network-stream (:type 'ssl) → 内部走
;; network-stream-open-tls, 它用 host 同时做 TCP、gnutls hostname 和 nsm
;; 验证。Gmail 场景 host=127.0.0.1 证书验证必挂, 且 :type 'tls 会先发
;; 明文 EHLO 探测 (隐式 TLS 回 alert 失败)。整体替换该函数 (仅拦截隧道):
;; plain TCP 连隧道 + gnutls-negotiate (hostname 用真实域名)。
;; 126 直连 (smtp.126.com) 不匹配拦截条件, 走原逻辑。
(defun my-network-stream-open-tls (orig-fn name buffer host service parameters)
  "Open Gmail SMTP via local socat tunnel (127.0.0.1:1465)."
  (if (and (string= host "127.0.0.1")
           (equal service 1465))
      (with-current-buffer buffer
        (let* ((start (point-max))
               (proc (open-network-stream name buffer "127.0.0.1" 1465
                                          :type 'plain
                                          :return-list nil)))
          (gnutls-negotiate :process proc :hostname "smtp.gmail.com")
          (let ((eoc (plist-get parameters :end-of-command))
                (capa-cmd (plist-get parameters :capability-command)))
            (list proc
                  (network-stream-get-response proc start eoc)
                  (network-stream-command proc capa-cmd eoc)
                  'tls))))
    (funcall orig-fn name buffer host service parameters)))
(advice-add 'network-stream-open-tls :around #'my-network-stream-open-tls)

(provide 'init-mail)

;; ================= 诊断通道: 允许 emacsclient 远程检查 =================
(server-start)

;; ================= Gnus: 启动不弹 auto-save 询问 =================
;; 上次 Gnus 未正常退出会残留 ~/.newsrc-dribble, 下次启动弹
;; "Gnus auto-save file exists. Do you want to read it?"。
;; 设为无条件自动读取该文件, 弹窗消失, 订阅状态照常恢复。
(setq gnus-always-read-dribble-file t)

;; ================= Gnus: 按邮箱账号分组 (Topic 模式) =================
;; 邮件组列表按账号分开展示, 一眼看出哪个组属于哪个邮箱。
;; 注意:
;;   1. 第一个 topic ("其他") 是所有未列出的新组的默认归属。
;;   2. Gnus 退出时会把 topic 结构存进 .newsrc.eld, 下次启动用保存值
;;      覆盖 init.el 的设置 —— 所以必须在进入组列表时强制重置 (下方 hook)。
;;   3. 2026-08 调整: Gmail 组直接放根 topic (名字 = Gmail 地址),
;;      126 作为根的子 topic (紧随其后)。
(defvar my-gnus-topic-alist
  `(("luongchinc@gmail.com"
     "INBOX" "Notes" "已发邮件" "所有邮件" "已加星标" "垃圾邮件" "已删除邮件")
    (,(concat "126 · " my-mail126-address)
     "nnimap+126:INBOX" "nnimap+126:草稿箱" "nnimap+126:已发送"
     "nnimap+126:已删除" "nnimap+126:垃圾邮件" "nnimap+126:病毒邮件"
     "nnimap+126:广告邮件" "nnimap+126:Notes")
    ("其他"
     )
    ("草稿"
     "nndraft:drafts")))

;; Gnus topic 树结构: 根 = Gmail 地址 (Gmail 组直接挂根下),
;; 126 紧随其后作为根的子 topic。⚠️ 必须同时设 topology 和 alist:
;; .newsrc.eld 的 setq 在 gnus-topic 加载前执行, 变量被 Gnus 启动重置为
;; nil → 渲染报 char-or-string-p nil (2026-08 实测)。
(defvar my-gnus-topic-topology
  '(("luongchinc@gmail.com" visible)
    (("126 · dok4ever123@126.com" visible nil nil))
    (("其他" visible))
    (("草稿" visible)))
  "Gnus topic 树结构 (根 = Gmail, 126 是根的子 topic).")

;; Gmail 本地文件夹自动订阅 (nnmaildir 只认顶层目录, 嵌套的 [Gmail]/*
;; 已建顶层符号链接 ~/Mail/gmail/<名字>, 组名即链接名)
(add-hook 'gnus-after-startup-hook
          (lambda ()
            (dolist (g '("Notes" "已发邮件" "所有邮件" "已加星标"
                         "垃圾邮件" "已删除邮件"))
              (unless (gnus-group-entry g)
                (ignore-errors (gnus-subscribe-group g))))))

;; 进入组列表时: 必须先设好 alist 再开 topic 模式 ——
;; gnus-topic-mode 启用时会立即按当前 alist 重绘列表,
;; 顺序反了就会用默认结构 (Gnus/misc)。
(add-hook 'gnus-group-mode-hook
          (lambda ()
            (setq gnus-topic-alist my-gnus-topic-alist)
            (gnus-topic-mode 1)))
;; 启动完成后也兜底一次 (防止 Gnus 内部流程再次载入旧结构)
(add-hook 'gnus-after-startup-hook
          (lambda ()
            (setq gnus-topic-alist my-gnus-topic-alist)))

;; ================= Gnus: summary 列表窗口固定 10 行 (一屏 10 条) =================
;; 默认 summary 占帧高 25% (一屏几十条), 改为固定 10 行高。
;; Gnus 窗口规格: 整数=固定行数, 浮点=比例。
;; 自适应: 窗口够高时固定 10 行, 窗口太矮时退回默认比例 (否则分割窗口
;; 会报 "Window too small for splitting")。
(defun my-gnus-article-layout ()
  "返回 Gnus article 布局: 窗口高度 >=18 行时 summary 固定 10 行, 否则用比例."
  (if (>= (window-height) 18)
      '(vertical 1.0 (summary 10 point) (article 1.0))
    '(vertical 1.0 (summary 0.25 point) (article 1.0))))
(with-eval-after-load 'gnus-win
  (setf (cdr (assq 'article gnus-buffer-configuration))
        '((my-gnus-article-layout))))

;; ================= Gnus: 真分页 (列表只显示 10 条, 页码切换) =================
;; 进入邮件组后列表只生成当前页的 10 条, 底部页码条点击切换页面。
;; 机制: gnus-summary-limit (官方 limit 命令同款) 过滤可见文章。
(require 'cl-lib)
(defvar my-gnus-page-size 10
  "Gnus summary 每页显示的条数.")

(defun my-gnus-summary-all-articles ()
  "返回当前邮件组全部文章号, 按 summary 实际显示顺序 (倒序: 最新在前)."
  (when (boundp 'gnus-newsgroup-headers)
    (mapcar #'mail-header-number
            (if gnus-article-sort-functions
                (gnus-sort-articles (copy-sequence gnus-newsgroup-headers))
              gnus-newsgroup-headers))))

(defvar my-gnus-summary-paging nil
  "内部标志: 分页刷新中, 防止 prepared-hook 递归.")

(defun my-gnus-summary-page-bar-string ()
  "生成列表内容底部的页码行: 页  1  2  [3]  ... 8 (可点击)."
  (let* ((all (my-gnus-summary-all-articles))
         (total (length all))
         (pages (max 1 (ceiling (/ (float total) my-gnus-page-size))))
         (page (my-gnus-summary-current-page))
         (from (max 1 (- page 4)))
         (to (min pages (+ page 4))))
    (concat
     "\n"
     (propertize "页  " 'face 'shadow 'follow-link nil)
     (mapconcat
      (lambda (p)
        (let ((cmd (lambda () (interactive) (my-gnus-summary-show-page p)))
              (map (make-sparse-keymap)))
          ;; Gnus 的 follow-link 会把 mouse-1 转成 mouse-2 (打开文章),
          ;; 所以 mouse-1/mouse-2 都绑翻页, 并用 follow-link nil 阻断转换
          (define-key map [mouse-1] cmd)
          (define-key map [mouse-2] cmd)
          (define-key map [return] cmd)
          (if (= p page)
              (propertize (format "  [%d]  " p)
                          'face 'highlight 'follow-link nil)
            (propertize (format "  %d  " p)
                        'face 'link 'keymap map 'follow-link nil
                        'mouse-face 'highlight))))
      (number-sequence from to) "")
     (if (< to pages)
         (propertize (format " .. %d" pages) 'face 'shadow 'follow-link nil)
       ""))))

(defun my-gnus-summary-page-bar-refresh ()
  "在 summary 列表末尾重建页码行 (真实文本行, 点击可靠)."
  (when (and (not my-gnus-summary-paging)
             (derived-mode-p 'gnus-summary-mode)
             (boundp 'gnus-newsgroup-headers)
             gnus-newsgroup-headers)
    (let ((inhibit-read-only t))
      (save-excursion        ; 不移动光标 (否则光标会被 insert 带到页码行)
        ;; 删除旧的页码行: 用 text-property 标记定位 (不能用位置记录 --
        ;; 翻页会重建 buffer, 旧位置会指向文章行中间, 误删内容)
        (let ((beg (text-property-any (point-min) (point-max)
                                      'my-gnus-page-bar t)))
          (when beg
            (delete-region beg (point-max))))
        ;; 在列表末尾插入新页码行 (整行带标记)
        (goto-char (point-max))
        (insert (propertize (my-gnus-summary-page-bar-string)
                            'my-gnus-page-bar t))))))
(add-hook 'gnus-summary-prepared-hook #'my-gnus-summary-page-bar-refresh)

(defun my-gnus-summary-show-page (page)
  "把 summary 列表 limit 到第 PAGE 页 (每页 my-gnus-page-size 条)."
  (interactive "nPage: ")
  (let* ((all (my-gnus-summary-all-articles))
         (total (length all))
         (pages (max 1 (ceiling (/ (float total) my-gnus-page-size))))
         (page (max 1 (min page pages)))
         (start (* (1- page) my-gnus-page-size))
         (articles (cl-subseq all start (min (+ start my-gnus-page-size) total))))
    (when articles
      (setq my-gnus-summary-paging t)
      (unwind-protect
          (gnus-summary-limit articles)
        (setq my-gnus-summary-paging nil))
      (my-gnus-summary-page-bar-refresh))))

(defvar-local my-gnus-summary-paged-group nil
  "已做过首屏分页的邮件组名 (组切换时重新分页).")

(defun my-gnus-summary-page-hook ()
  "进入邮件组后自动显示第 1 页 (仅当切换到新邮件组时执行一次,
避免 Gnus 内部刷新或用户 /w 恢复全量时被踢回第 1 页)."
  (when (and (not my-gnus-summary-paging)
             (boundp 'gnus-newsgroup-headers)
             gnus-newsgroup-headers
             (not (equal my-gnus-summary-paged-group gnus-newsgroup-name)))
    (setq my-gnus-summary-paged-group gnus-newsgroup-name)
    (my-gnus-summary-show-page 1)))
(add-hook 'gnus-summary-prepared-hook #'my-gnus-summary-page-hook)

(defun my-gnus-summary-current-page ()
  "当前页号 (根据 limit 第一篇文章在全集中的位置计算)."
  (let* ((all (my-gnus-summary-all-articles))
         (first (and (boundp 'gnus-newsgroup-limit)
                     (car gnus-newsgroup-limit))))
    (if (and all first)
        (1+ (/ (or (cl-position first all) 0) my-gnus-page-size))
      1)))

(defun my-gnus-summary-page-indicator ()
  "生成页码条: [1] 2 3 4 ... 8.
从 summary buffer 读数据 (通过全局变量 gnus-summary-buffer),
因此挂在列表窗口或正文窗口的 mode-line 都能正确显示."
  (let ((sbuf (and (boundp 'gnus-summary-buffer)
                   (get-buffer gnus-summary-buffer))))
    (when (and sbuf (buffer-local-value 'gnus-newsgroup-headers sbuf))
      (with-current-buffer sbuf
        (let* ((all (my-gnus-summary-all-articles))
               (total (length all))
               (pages (max 1 (ceiling (/ (float total) my-gnus-page-size))))
               (page (my-gnus-summary-current-page))
               (from (max 1 (- page 4)))
               (to (min pages (+ page 4))))
          (concat
           (mapconcat
            (lambda (p)
              (if (= p page)
                  (propertize (format "[%d]" p) 'face 'mode-line-highlight)
                (propertize (format " %d" p)
                            'face 'link
                            'mouse-face 'highlight
                            'local-map
                            (make-mode-line-mouse-map
                             'mouse-1
                             (lambda ()
                               (interactive)
                               (my-gnus-summary-show-page p))))))
            (number-sequence from to) "")
           (if (< to pages) (format " .. %d" pages) "")))))))

;; mode-line 返回按钮: 鼠标点击返回上一个页面
;; (正文窗口 → 邮件列表; 邮件列表 → 所有邮箱)
(defun my-gnus-back-button ()
  "生成 mode-line 上的 [← 返回] 按钮."
  (propertize "  [← 返回]  "
              'face 'link
              'mouse-face 'highlight
              'help-echo "返回上一个页面"
              'local-map
              (make-mode-line-mouse-map
               'mouse-1
               (lambda ()
                 (interactive)
                 (cond
                  ((derived-mode-p 'gnus-article-mode)
                   (gnus-article-show-summary))   ; 正文 → 邮件列表
                  ((derived-mode-p 'gnus-summary-mode)
                   (gnus-summary-exit)))))))       ; 列表 → 所有邮箱

;; 页码条挂到列表窗口和正文窗口的标准 mode-line (每次重绘自动刷新,
;; 不依赖 Gnus 内部的 mode-line 更新链, 最可靠)
(add-hook 'gnus-summary-mode-hook
          (lambda ()
            (setq-local mode-line-format
                        (append mode-line-format
                                '((:eval (my-gnus-back-button))
                                  (:eval (my-gnus-summary-page-indicator)))))))
(add-hook 'gnus-article-mode-hook
          (lambda ()
            (setq-local mode-line-format
                        (append mode-line-format
                                '((:eval (my-gnus-back-button))
                                  (:eval (my-gnus-summary-page-indicator)))))))

;; 菜单栏加"邮件导航"菜单 (GUI 友好, 可靠显示)
(with-eval-after-load 'gnus-sum
  (easy-menu-define nil gnus-summary-mode-map "邮件导航"
    '("邮件导航"
      ["返回所有邮箱" gnus-summary-exit t]
      ["退出 Gnus" gnus-group-exit t])))
(with-eval-after-load 'gnus-art
  (easy-menu-define nil gnus-article-mode-map "邮件导航"
    '("邮件导航"
      ["返回邮件列表" gnus-article-show-summary t]
      ["返回所有邮箱" gnus-summary-exit t])))

(with-eval-after-load 'gnus-sum
  ;; 倒序显示: 最新邮件在最上面 (邮件客户端惯例)
  (setq gnus-article-sort-functions '((not gnus-article-sort-by-number)))
  ;; 关闭线程模式: 平铺列表, 分页才精确 (线程模式下线程首篇不在本页
  ;; 会整线程隐藏, 导致某些页只有 8-9 条)
  (setq gnus-show-threads nil))

;; ================= Emacs 内 bash shell =================
;; M-x shell 使用 bash 5.3 (nix), 而非 macOS 自带的老版 bash 3.2。
;; 只影响 M-x shell; 内部 shell-command 仍走默认 sh, 互不干扰。
(when-let ((bash (executable-find "bash")))
  (setq explicit-shell-file-name bash))

;; ================= IDE 外观 + 模块加载 (VSCode-like) =================
;; 模块化: lisp/ 下的模块按依赖顺序加载
(let ((lisp-dir (expand-file-name "lisp" user-emacs-directory)))
  (when (file-exists-p lisp-dir)
    (add-to-list 'load-path lisp-dir)))
;; ide.el 提供主题/标签页/侧边栏/Dashboard 等外观层 (含 package.el 初始化)
(when (file-exists-p (expand-file-name "ide.el" user-emacs-directory))
  (load (expand-file-name "ide.el" user-emacs-directory)))

;; 禁用 electric-indent-mode (Emacs 默认开启): 回车后自动缩进,
;; 连续按两次回车缩进会逐级增加 (用户不需要, 2026-08)。
;; prog-mode 的缩进由 init-simple-indent 自定义 RET 管理, 不受影响。
(electric-indent-mode -1)
;; 功能模块 (依赖 ide.el 的 package.el 初始化)
(require 'init-completion nil t)
(require 'init-tools nil t)
(require 'init-env nil t)
(require 'init-nix nil t)   ; Nix 语言 (nix-mode + nixd LSP, 依赖 init-env 的 treesit-auto 排除)
(require 'init-term nil t)
(require 'init-server nil t)   ; 服务器管理 (TRAMP + vterm), 清单在 servers.el
(require 'init-dev nil t)
(require 'init-simple-indent nil t)   ; 编程语言统一简单缩进 (TAB 固定 2 空格 + RET 智能继承)
(require 'init-meow nil t)
(require 'init-org nil t)
(require 'init-dashboard nil t)   ; 自写双栏 Dashboard 主页 (依赖 org/projectile/recentf, 放 org 后)
(require 'init-lazycat nil t)

;; ================= 126 IMAP: 登录后发 ID 命令 (网易风控) =================
;; 症状: Gnus 进 nnimap+126 报 "NO SELECT Unsafe Login. Please contact kefu@188.com"
;; 根因: 网易 Coremail 要求客户端 LOGIN 后发 IMAP ID 命令 (RFC 2971) 声明
;;       客户端身份, 不发的会话 SELECT 被拒 (LIST 正常, 读文件夹被拦)。
;;       手工 socket 测试: LOGIN → ID → SELECT 成功; 不发 ID → SELECT Unsafe Login。
;; 修复: advice 包 nnimap-login, 登录成功 (返回 t) 后立刻发 ID 命令。
;;       仅对 126 (imap.126.com) 生效, 不影响 Gmail (nnmaildir 不经过这里)。
;; ⚠️ 注意: 此段是未提交修改, git checkout/reset 会弄丢它 (2026-08-09 实测
;;       丢过一次导致 126 复发) — 若要提交, 记得一起 commit。
(with-eval-after-load 'nnimap
  (defun my-nnimap-send-id-after-login (&rest args)
    "nnimap-login 成功后发 IMAP ID 命令 (126 风控要求, 2026-08 实测)."
    (let ((result (apply args)))
      (when (and result
                 (bufferp (current-buffer))
                 (string-match-p "126"
                                 (or (bound-and-true-p nnimap-address) "")))
        (condition-case nil
            (nnimap-command
             "ID (\"name\" \"Gnus\" \"version\" \"%s\" \"vendor\" \"GNU\" \"os\" \"%s\")"
             gnus-version system-type)
          (error nil)))
      result))
  (advice-add 'nnimap-login :around #'my-nnimap-send-id-after-login))
;;; init.el ends here
