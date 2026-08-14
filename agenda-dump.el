;;; agenda-dump.el --- Dashboard agenda 数据计算 (子进程专用, --quick 轻量加载) -*- lexical-binding: t -*-
;;;
;;; 背景 (2026-08-14): Dashboard 的 Agenda 卡片由主 Emacs 派生子进程计算,
;;; 避免 org-agenda 在 GUI 下逐个打开 agenda 文件 (~2s/文件) 冻结界面。
;;; 早期版本子进程加载完整 init.el, batch init 要 ~6s, 卡片占位太久。
;;; 本脚本只 require org + org-agenda (内置, ~1s), agenda 文件列表由
;;; 主 Emacs 通过命令行传入, 不复制配置 (改 org-agenda-files 自动生效)。
;;;
;;; 调用方式 (由 ide.el 的 my-dash--agenda-load-async 派生):
;;;   emacs --quick -l agenda-dump.el \
;;;         --eval "(my-agenda-dump '(\"~/org/inbox.org\" ...) \"/tmp/my-dash-agenda.out\")"

(require 'org)
(let ((inhibit-message t))
  (require 'org-agenda))

(defun my-agenda-dump (files out-file)
  "Compute dashboard agenda rows for FILES and write them to OUT-FILE.
与 ide.el 旧 my-dash--agenda-data 同一逻辑: org-agenda-list 渲染进当前
buffer (org-agenda-prepare-window 的 current-buffer==abuf 短路, 零窗口操作),
过滤出带时刻/TODO/Sched 的行, 取前 5 行, prin1 成 sexp 落盘。"
  (let ((org-agenda-window-setup 'current-window)
        (org-agenda-sticky nil)
        ;; 固定 buffer 名并让 current-buffer 就是它, 避免 org-agenda
        ;; pop-to-buffer-same-window 切走窗口 (GUI 下会闪空白页)
        (org-agenda-buffer-name "*Org Agenda*")
        (org-agenda-buffer-tmp-name nil)
        (org-agenda-doing-sticky-redo nil)
        ;; 摘掉 org-clock-load: 打开 agenda 文件会触发 org-mode-hook →
        ;; org-clock-load → load-file org-clock-save.el, 若有待恢复的 clock
        ;; 会 y-or-n-p 询问 → batch 子进程阻塞挂死 (2026-08-14 排坑)。
        (org-mode-hook (remove 'org-clock-load org-mode-hook))
        (org-agenda-files files))
    (with-current-buffer (get-buffer-create org-agenda-buffer-name)
      (let ((inhibit-read-only t))
        (erase-buffer))
      (org-agenda-list)
      (let ((lines '()))
        (goto-char (point-min))
        (while (not (eobp))
          (let ((trimmed (string-trim
                          (buffer-substring-no-properties
                           (line-beginning-position) (line-end-position)))))
            (when (and (> (length trimmed) 0)
                       (or (string-match-p "[0-9]\\{2\\}:[0-9]\\{2\\}" trimmed)
                           (string-match-p "\\(?:TODO\\|DONE\\|Sched\\(?:\\|ed\\)\\.?\\)" trimmed)))
              (push (cons trimmed nil) lines)))
          (forward-line 1))
        (with-temp-file out-file
          (insert (prin1-to-string (seq-take (nreverse lines) 5))))))))

(provide 'agenda-dump)
;;; agenda-dump.el ends here
