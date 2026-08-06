;;; init-completion.el --- Minibuffer 搜索 + 代码补全 -*- lexical-binding: t -*-

;;; Commentary:
;;
;; vertico: minibuffer 候选列表 (替代默认)
;; orderless: 模糊匹配 (空格分隔关键词)
;; consult: 高级搜索命令 (ripgrep / 行内搜索 / buffer 切换)
;; marginalia: minibuffer 条目右侧注解
;; embark: 光标处上下文操作 (类似右键菜单)
;; corfu: 代码补全弹窗 (轻量, 基于 child frame)

;;; Code:

;; ---------- vertico: minibuffer 候选列表 ----------
(use-package vertico
  :ensure t
  :init
  (vertico-mode 1)
  :custom
  (vertico-count 12)                       ; 候选条目数
  (vertico-resize 'grow)                   ; 候选多时自动增高
  (vertico-cycle t))                       ; 到顶/底循环

;; ---------- orderless: 模糊匹配 ----------
;; 空格分隔关键词, 顺序无关: "foo bar" 匹配含 foo 和 bar 的条目
(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

;; ---------- marginalia: minibuffer 注解 ----------
;; 文件显示大小/日期, 函数显示参数/文档, buffer 显示 mode
(use-package marginalia
  :ensure t
  :init
  (marginalia-mode 1))

;; ---------- consult: 高级搜索命令 ----------
(use-package consult
  :ensure t
  :bind
  (;; C-x b 切换 buffer (带预览)
   ("C-x b" . consult-buffer)
   ;; M-y 粘贴历史 (带候选)
   ("M-y" . consult-yank-pop)
   ;; 搜索
   ("M-s M-s" . consult-line)              ; 当前 buffer 行内搜索
   ("M-s g" . consult-ripgrep)             ; 项目内全局搜索
   ("M-s f" . consult-fd)                  ; 项目内文件搜索
   ("M-s i" . consult-imenu)              ; 函数/变量跳转
   ("M-s o" . consult-outline)             ; 大纲跳转
   ;; bookmark
   ("M-s m" . consult-bookmark))
  :custom
  (consult-async-min-input 1)
  (consult-narrow-key nil)
  (consult-project-function #'project-find-functions))

;; ---------- embark: 上下文操作 ----------
;; M-o 或 C-. 在光标处弹出操作菜单 (打开/复制/删除/搜索等)
(use-package embark
  :ensure t
  :bind
  (("C-." . embark-act)                    ; 光标处上下文操作
   ("M-o" . embark-act)                    ; 同上, 类似 VSCode
   ("C-h B" . embark-bindings))            ; 查看所有按键
  :config
  ;; embark 和 consult 联动: consult 候选里也能用 embark
  (setq embark-action-indicator
        (lambda (map &optional _target)
          (when (and map (derived-mode-p 'minibuffer-mode))
            (format "Embark: %s" (key-binding (kbd "C-.") map)))))

;; embark-consult 集成
(use-package embark-consult
  :ensure t
  :after (embark consult)
  :demand t
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

;; ---------- corfu: 代码补全弹窗 ----------
;; 轻量, 基于 child frame, 不依赖 company
(use-package corfu
  :ensure t
  :init
  (global-corfu-mode 1)
  :custom
  (corfu-auto t)                           ; 自动弹出
  (corfu-auto-delay 0.2)
  (corfu-auto-prefix 2)                    ; 至少输入 2 字符才触发
  (corfu-cycle t)                          ; 循环候选
  (corfu-quit-no-match 'separator)
  (corfu-preview-current t)
  (corfu-preselect 'prompt)
  :config
  ;; Tab 接受补全
  (define-key corfu-map (kbd "TAB") #'corfu-insert)
  (define-key corfu-map (kbd "<tab>") #'corfu-insert))

;; corfu 配 orderless: 补全时也用模糊匹配
(use-package corfu
  :custom
  (corfu-auto t))

;; cape: corfu 的额外补全后端 (dictionary/abbrev/file/dabbrev)
(use-package cape
  :ensure t
  :init
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-dict))

;; minibuffer 里也用 corfu (M-x 补全时)
(defun corfu-enable-in-minibuffer ()
  "Minibuffer 里也启用 corfu."
  (when (minibufferp)
    (corfu-mode 1)))
(add-hook 'minibuffer-setup-hook #'corfu-enable-in-minibuffer)

;; savehist: 记录 minibuffer 历史, vertico 排序用
(use-package savehist
  :ensure nil
  :init
  (savehist-mode 1))

(provide 'init-completion)
;;; init-completion.el ends here
