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
;;; 检查项: .elc 污染 / dired-subtree 真加载 / dired 键位+auto-revert / 中文紧贴标记的强调 (CJK emphasis) /
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

  ;; 4a. dired 增强: C-c o → 系统默认应用打开, 默认 hide-details
  (with-current-buffer (dired-noselect "/tmp/")
    (let ((cco (lookup-key dired-mode-map (kbd "C-c o")))
          (hdd (and (boundp 'dired-hide-details-mode) dired-hide-details-mode)))
      (push (format "[%s] dired C-c o → my-dired-open-default-app (实际 %s)" (if (eq cco 'my-dired-open-default-app) "OK" "FAIL") cco) out)
      (push (format "[%s] dired 默认隐藏详情 (实际 %S)" (if hdd "OK" "FAIL") hdd) out)))

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

  ;; 5e. 中文紧贴标记的强调 (2026-10-05 新增: buffer 高亮 + HTML 导出都认汉字边界)
  (progn
    (require 'org nil t)
    (require 'org-element nil t)
    (require 'ox-html nil t)
    (let ((marks (and (boundp 'my-org-emph-cjk-marks) my-org-emph-cjk-marks))
          (inst (and (boundp 'my-org-emph-cjk--installed) my-org-emph-cjk--installed))
          (adv (advice-member-p 'my-org-element--parse-generic-emphasis
                                'org-element--parse-generic-emphasis)))
      (push (format "[%s] CJK 强调: 标记表只有 * 粗体 (实际 %S)" (if (equal marks '("*")) "OK" "FAIL") marks) out)
      (push (format "[%s] CJK 强调: font-lock 规则已装 (实际 %S)" (if inst "OK" "FAIL") inst) out)
      (push (format "[%s] CJK 强调: 导出解析函数已替换 (实际 %S)" (if adv "OK" "FAIL") (and adv t)) out))
    ;; 功能面: 汉字紧贴的 **粗体** 在 buffer 里应变粗, 导出应变 <b>
    (with-temp-buffer
      (insert "这是**粗体**字")
      (org-mode)
      (font-lock-ensure)
      (goto-char (point-min))
      (search-forward "粗体")
      (let ((face (get-char-property (match-beginning 0) 'face))
            (html (with-current-buffer (org-html-export-as-html nil nil nil t)
                    (buffer-string))))
        (push (format "[%s] CJK 强调: buffer 里「粗体」是 bold (实际 %S)" (if (memq 'bold face) "OK" "FAIL") face) out)
        (push (format "[%s] CJK 强调: 导出 HTML 含 <b><b>粗体</b></b> (实际 %S)"
                      (if (string-match-p "<b><b>粗体</b></b>" html) "OK" "FAIL")
                      (and (string-match-p "<b>" html) t))
              out)))
    ;; 兜底: "/" 不在标记表里, «读/写/执行» 的 写 不能被当强调 (变斜体)
    (with-temp-buffer
      (insert "他/她 和 读/写/执行")
      (org-mode)
      (font-lock-ensure)
      (goto-char (point-min))
      (search-forward "写")
      (let ((face (get-char-property (match-beginning 0) 'face)))
        (push (format "[%s] CJK 强调兜底: 「读/写/执行」的 写 没变斜体 (实际 %S)"
                      (if (memq 'italic face) "FAIL" "OK") face)
              out)))
    ;; 守卫: 只在该位置真是强调对象时点亮 (固定宽度行 : xxx 里不能亮 — 导出里不算强调)
    (with-temp-buffer
      (insert "段落 这是**重点**字\n\n: 固定宽度 这是**重点**字\n")
      (org-mode)
      (font-lock-ensure)
      (goto-char (point-min))
      (let (res)
        (while (re-search-forward "重点" nil t)
          (let ((f (get-text-property (match-beginning 0) 'face)))
            (push (if (and f (or (eq f 'bold) (and (listp f) (memq 'bold f)))) "bold" "-") res)))
        (let ((res (nreverse res)))
          (push (format "[%s] CJK 强调守卫: 段落亮/固定宽度行不亮 (实际 %S)"
                        (if (equal res '("bold" "-")) "OK" "FAIL") res)
                out)))))

  ;; 6. 干净启动无初始化错误 (查 *Warnings* 是否有 initialization)
  (let ((w (get-buffer "*Warnings*")))
    (if w
        (with-current-buffer w
          (let ((txt (buffer-string)))
            (push (format "[%s] 无 initialization 警告 (Warnings buffer 存在, %d 字符)" (if (string-match-p "initialization" txt) "FAIL" "OK") (length txt)) out)))
      (push "[OK] 无 *Warnings* buffer (启动完全干净)" out)))

  (mapconcat #'identity (nreverse out) "\n"))
