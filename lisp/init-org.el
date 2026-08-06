;;; init-org.el --- Org Mode (笔记/任务/文学编程) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; org: Emacs 杀手级应用 — 大纲/任务管理/笔记/文学编程/文档导出
;; org-modern: 现代化外观 (符号替代星号, TODO 彩色标签)
;; evil-org: evil 快捷键集成 (h/l 升降级, Tab 折叠, 等)
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

;; ---------- evil-org: evil 快捷键集成 ----------
;; 为 org-mode 提供 evil 风格的导航和编辑:
;;   gh/gj/gk/gl — promote/demote/move headline
;;   Tab/Shift-Tab — fold/expand
;;   正常的 j/k/h/l 导航
(use-package evil-org
  :ensure t
  :after (evil org)
  :hook (org-mode . evil-org-mode)
  :config
  (evil-org-set-key-theme
   '(navigation insert textobjects additional))
  ;; agenda 也用 evil 快捷键 (j/k 上下, Tab 切换)
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys))

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

;; ---------- 全局快捷键 ----------
(global-set-key (kbd "C-c a") #'org-agenda)         ; 日程/任务总览
(global-set-key (kbd "C-c c") #'org-capture)        ; 快速捕获
(global-set-key (kbd "C-c l") #'org-store-link)      ; 存储链接 (org 文件可插入)

;; ---------- 确保 org 目录存在 ----------
(unless (file-exists-p org-directory)
  (make-directory org-directory t))

(provide 'init-org)
;;; init-org.el ends here
