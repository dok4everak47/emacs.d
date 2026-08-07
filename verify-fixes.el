;;; verify-fixes.el --- 配置自检: 重启后一键验证修复点 ---
;;;
;;; 用途: 每次修改 ~/.emacs.d 配置 (lisp/*.el / init.el) 并重启后,
;;; 跑一遍确认没把环境改坏 (2026-08 事故后建立的自检习惯)。
;;;
;;; 用法 (重启 Emacs 后, 终端执行):
;;;   /Applications/Emacs.app/Contents/MacOS/bin/emacsclient -e "$(cat ~/.emacs.d/verify-fixes.el)"
;;;
;;; 输出全部 "[OK]" 即通过; 任何 "[FAIL]" 说明对应配置未生效。
;;; 注意: 输出是一行 \n 转义的字符串, 视觉上正常显示, 不影响判断。
;;;
;;; 检查项: .elc 污染 / dired-subtree 真加载 / dired 键位+auto-revert /
;;; flymake-consult 绑定 / vterm+vundo+impatient :custom 变量 / 启动警告。
;;;
;;; 2026-08: 因 batch 编译生成有毒 .elc 和 use-package :custom 静默失效
;;; 两次事故而创建。新增配置后应把新变量/键位追加到下方检查列表。
;;; -*- lexical-binding: t -*-

(let ((out '())
      (pass t))
  (push "===== Emacs 修复验证 =====" out)
  (push (format "Emacs %s" emacs-version) out)
  (push "" out)

  ;; 1. 无 .elc 污染 (上次事故根源)
  (let ((elc (expand-file-name "lisp/init-meow.elc" user-emacs-directory)))
    (push (format "[%s] 无 .elc 污染 (init-meow.elc 不存在): %s"
                  (if (not (file-exists-p elc)) "OK" "FAIL") (not (file-exists-p elc)))
          out))

  ;; 2. dired-subtree 真加载 (featurep=t 而非 autoload stub)
  (let ((ok (featurep 'dired-subtree)))
    (push (format "[%s] dired-subtree 已真加载: %s" (if ok "OK" "FAIL") ok) out))

  ;; 3. dired 绑定: i / TAB / C-x M-o / auto-revert
  (with-current-buffer (dired-noselect "/tmp/")
    (let ((i (key-binding (kbd "i")))
          (tab (key-binding (kbd "TAB")))
          (omo (key-binding (kbd "C-x M-o")))
          (ar dired-auto-revert-buffer))
      (push (format "[%s] i → dired-subtree-toggle (实际 %s)" (if (eq i 'dired-subtree-toggle) "OK" "FAIL") i) out)
      (push (format "[%s] TAB → dired-subtree-cycle (实际 %s)" (if (eq tab 'dired-subtree-cycle) "OK" "FAIL") tab) out)
      (push (format "[%s] C-x M-o → dired-omit-mode (实际 %s)" (if (eq omo 'dired-omit-mode) "OK" "FAIL") omo) out)
      (push (format "[%s] auto-revert = dired-directory-changed-p (实际 %S)" (if (eq ar 'dired-directory-changed-p) "OK" "FAIL") ar) out)))

  ;; 4. flymake/consult 嵌套守卫: C-c ! f 应绑定 consult-flymake
  (progn
    (require 'consult nil t)
    (require 'flymake nil t)
    (let ((kf (lookup-key flymake-mode-map (kbd "C-c ! f"))))
      (push (format "[%s] C-c ! f → consult-flymake (实际 %s)" (if (eq kf 'consult-flymake) "OK" "FAIL") kf) out)))

  ;; 5. :custom 变量修复 (require 后查值)
  (progn
    (require 'vterm nil t)
    (require 'vundo nil t)
    (require 'impatient-mode nil t)
    (let ((vs (and (boundp 'vterm-max-scrollback) vterm-max-scrollback))
          (vh (and (boundp 'vundo-window-max-height) vundo-window-max-height))
          (id (and (boundp 'impatient-mode-delay) impatient-mode-delay))
          (fm (boundp 'flymake-margin-enabled)))
      (push (format "[%s] vterm-max-scrollback = 10000 (实际 %S)" (if (eq vs 10000) "OK" "FAIL") vs) out)
      (push (format "[%s] vundo-window-max-height = 12 (实际 %S)" (if (eq vh 12) "OK" "FAIL") vh) out)
      (push (format "[%s] impatient-mode-delay = 0.5 (实际 %S)" (if (= id 0.5) "OK" "FAIL") id) out)
      (push (format "[%s] flymake-margin-enabled 已删除 (boundp=%s)" (if (not fm) "OK" "FAIL") fm) out)))

  ;; 6. 干净启动无初始化错误 (查 *Warnings* 是否有 initialization)
  (let ((w (get-buffer "*Warnings*")))
    (if w
        (with-current-buffer w
          (let ((txt (buffer-string)))
            (push (format "[%s] 无 initialization 警告 (Warnings buffer 存在, %d 字符)" (if (string-match-p "initialization" txt) "FAIL" "OK") (length txt)) out)))
      (push "[OK] 无 *Warnings* buffer (启动完全干净)" out)))

  (mapconcat #'identity (nreverse out) "\n"))
