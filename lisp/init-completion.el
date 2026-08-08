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
  (consult-narrow-key nil))
  ;; consult 不再绑 consult-project-function: consult-projectile 接管
  ;; 项目相关候选 (consult-projectile-find-file/switch-project/recentf)。
  ;; dired-sidebar 走 projectile 检测根目录 — 三者联动。

;; ---------- consult-projectile: 项目命令 (consult + projectile) ----------
;; 替代内置 project.el 的 C-x p 前缀; projectile 全局检测项目 + 缓存。
;; C-c p 是 projectile 默认前缀, 这里把候选升级为 consult 风格
;; (vertico+orderless 模糊)。popper 已占 C-c p p/t/o, 不动;
;; 切项目改用 C-c p P (大写, 易记 "Project switch")。
;;
;; ⚠️ consult-projectile 包所有命令都走同一个 consult-projectile 入口,
;; prompt 写死 "Switch to:" (源码 :prompt 不分命令) — 选文件时显示
;; "Switch to:" 不贴切。包装函数绕过入口, 直接用 consult--multi +
;; 对应 source, prompt 改为各自的语义 ("Find file:" 等)。
(use-package consult-projectile
  :ensure t
  :demand t                                   ; 不 :after, 自己 require
  :config
  (require 'consult)
  (require 'projectile)
  ;; 包装: 直接调 consult--multi 用单一 source, prompt 自己写
  (defun my-consult-projectile--run (source prompt)
    "用 consult--multi 跑单一 SOURCE, prompt 用 PROMPT."
    (when-let (cand (consult--multi (list source) :prompt prompt :sort nil))
      (funcall (plist-get source :action) (car cand))))
  (defun my-consult-projectile-find-file ()
    "项目内找文件 (prompt 改正, 不显示 Switch to)."
    (interactive)
    (my-consult-projectile--run consult-projectile--source-projectile-file "Find file: "))
  (defun my-consult-projectile-recentf ()
    "项目 recentf."
    (interactive)
    (my-consult-projectile--run consult-projectile--source-projectile-recentf "Recent file: "))
  (defun my-consult-projectile-switch-to-buffer ()
    "项目 buffer."
    (interactive)
    (my-consult-projectile--run consult-projectile--source-projectile-buffer "Switch to buffer: "))
  (defun my-consult-projectile-find-dir ()
    "项目目录."
    (interactive)
    (my-consult-projectile--run consult-projectile--source-projectile-dir "Find directory: "))
  (defun my-consult-projectile-switch-project ()
    "切项目 (默认动作: 找文件, consult-projectile-use-projectile-switch-project 控制)."
    (interactive)
    (my-consult-projectile--run consult-projectile--source-projectile-project "Switch project: "))
  ;; 覆盖 projectile 默认候选为 consult 风格 (popper 的 C-c p p/t/o 不动)
  (define-key projectile-mode-map (kbd "C-c p f") #'my-consult-projectile-find-file)
  (define-key projectile-mode-map (kbd "C-c p r") #'my-consult-projectile-recentf)
  (define-key projectile-mode-map (kbd "C-c p b") #'my-consult-projectile-switch-to-buffer)
  (define-key projectile-mode-map (kbd "C-c p d") #'my-consult-projectile-find-dir)
  (define-key projectile-mode-map (kbd "C-c p P") #'my-consult-projectile-switch-project))

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
            (format "Embark: %s" (key-binding (kbd "C-.") map))))))

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
