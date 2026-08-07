;;; init-server.el --- 服务器管理 (TRAMP + vterm) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; 用 Emacs 管理远程服务器: TRAMP 远程文件/目录 + vterm SSH 终端。
;; 服务器清单在 ~/.emacs.d/servers.el (私有, gitignore, 不入库):
;;   (setq my-servers '(("blog (Laravel)" . "/ssh:blog:/home/admin")))
;; SSH 别名在 ~/.ssh/config (Host 块)。
;;
;; 用法 (菜单栏 "服务器" 或快捷键):
;;   C-x C-f /ssh:blog:/home/admin/blog/  直接编辑远程文件 (保存即上传)
;;   M-x my-server-dired                   浏览远程目录 (dired)
;;   M-x my-server-vterm                   vterm SSH 登录服务器
;;   M-x my-server-browse-files            选择并打开远程文件
;;
;; TRAMP 免密依赖 SSH key (ssh-copy-id 配好), 首次连接问密码属正常。

;;; Code:

(require 'tramp)
(require 'dired)

;; ---------- 服务器清单 (私有文件, 不存在则空) ----------
(defvar my-servers nil
  "服务器清单 alist: ((\"显示名\" . \"/ssh:别名:/远程路径\") ...)。
定义在 ~/.emacs.d/servers.el (gitignore, 不入库)。")
(load (expand-file-name "servers.el" user-emacs-directory) t)

;; ---------- 选择服务器 ----------
(defun my-server-pick (&optional prompt)
  "交互选择服务器, 返回其 TRAMP 根路径。"
  (interactive)
  (if (null my-servers)
      (user-error "服务器清单为空: 在 ~/.emacs.d/servers.el 里添加 (setq my-servers '((\"名字\" . \"/ssh:别名:/路径\")))")
    (let* ((names (mapcar #'car my-servers))
           (name (completing-read (or prompt "选择服务器: ") names nil t))
           (entry (assoc name my-servers)))
      (cdr entry))))

;; ---------- dired 远程目录 (像 Finder 一样管文件) ----------
(defun my-server-dired ()
  "用 dired 打开所选服务器的远程家目录 (TRAMP)。"
  (interactive)
  (dired (my-server-pick "选择服务器 (打开远程目录): ")))

;; ---------- vterm SSH 终端 ----------
(defun my-server-host-of (root)
  "从 TRAMP 根路径 /ssh:别名:/路径 提取 SSH 别名。
例: (my-server-host-of \"/ssh:blog:/home/admin\") => \"blog\""
  (cadr (split-string root ":")))

(defun my-server-vterm ()
  "打开 vterm 并 SSH 登录所选服务器。"
  (interactive)
  (let* ((root (my-server-pick "选择服务器 (SSH 登录): "))
         (host (my-server-host-of root)))
    (vterm)
    (with-current-buffer (current-buffer)
      (vterm-send-string (format "ssh %s" host))
      (vterm-send-return))))

;; ---------- 浏览并打开远程文件 ----------
(defun my-server-browse-files ()
  "在所选服务器上用 TRAMP 浏览并打开文件 (minibuffer 补全)。"
  (interactive)
  (let ((root (my-server-pick "选择服务器 (打开文件): ")))
    (find-file (read-file-name (format "远程文件 (%s): " root)
                               root nil nil
                               (when (and (> (length root) 0)
                                          (string-suffix-p "/" root))
                                 root)))))

;; ---------- 菜单栏 "服务器" 入口 (GUI 友好, 不用记快捷键) ----------
(easy-menu-define nil global-map "服务器"
  '("服务器"
    ["打开远程目录 (dired)" my-server-dired t]
    ["SSH 终端登录 (vterm)" my-server-vterm t]
    ["浏览并打开远程文件" my-server-browse-files t]
    "---"
    ["编辑服务器清单 (servers.el)" (find-file (expand-file-name "servers.el" user-emacs-directory)) t]))

(provide 'init-server)
;;; init-server.el ends here
