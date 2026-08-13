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

;; ---------- consult-dir: 目录选择 (C-x D 选目录后进 dired) ----------
;; C-x d 是原生 dired; C-x D 弹 consult-dir 候选 (项目根/项目/recentf/bookmark
;; + 输入历史) 选目录后打开 dired。解决 "v翻历史目录" 需求 — 原生
;; read-file-name 的 file-name-history 因 vertico remap M-n 为翻候选而看不到;
;; consult-dir 把历史/项目目录当候选列出。
;; 窄化 (narrow) 快速过滤单个源: 输 `p` 只看 Projects、`h` 只看输入历史、
;; `r` 只看 Recentf dirs、`.` 只看当前/项目根 — 不用一直往下拉。
(use-package consult-dir
  :ensure t
  :config
  ;; 增加 "输入历史" 候选源: 列出 file-name-history 里的路径 (C-x d 输过的).
  ;; consult--multi 源 = 符号, 值 = plist(:enabled/:items 为函数)。
  ;; 追加到 sources 末尾 (add-to-list ... t), 避免把 Projects/recentf 源挤下去.
  (defvar consult-dir--source-file-name-history
    `( :name "Input history"
       :narrow ?h
       :category file
       :face consult-file
       :history file-name-history
       :items ,#'(lambda ()
                   (seq-take
                    (delete-dups
                     (cl-remove-if-not
                      (lambda (f)
                        (or (string-suffix-p "/" f)
                            (file-directory-p (expand-file-name f))))
                      file-name-history))
                    10))))
  (add-to-list 'consult-dir-sources
               'consult-dir--source-file-name-history t))

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
  ;; ⚠️ consult-projectile-use-projectile-switch-project 是 defvar 不是 defcustom,
  ;; use-package :custom 对 defvar 无效 (customize-set-variable 跳过非 defcustom)。
  ;; 必须用 :config + setq。t = 切项目走 projectile-switch-project
  ;; (项目根 + projectile-switch-project-action); nil = 走 consult-projectile--file
  (setq consult-projectile-use-projectile-switch-project t)
  ;; 包装: 调 consult-projectile (包入口) 但 :around advice 动态改 :prompt
  ;; 不绕过包入口, 沿用它正确的 action 分发 (避免直接调 consult--multi
  ;; 带来的 :action 分发坑: Args out of range)。
  (defvar my-consult-projectile--prompt nil
    "当前要替换的 prompt; nil 时用包默认 \"Switch to: \"。
let 动态绑定, :around advice 读取。")
  (advice-add 'consult--multi :around
             (lambda (orig sources &rest opts)
               (let ((prompt (plist-get opts :prompt)))
                 (when (and my-consult-projectile--prompt
                            (string= prompt "Switch to: "))
                   (setq opts (plist-put opts :prompt
                                         my-consult-projectile--prompt)))
                 (apply orig sources opts))))
  (defun my-consult-projectile--run (source-sym prompt)
    "跑单一 SOURCE-SYM source, PROMPT 是 minibuffer 提示文字."
    (let ((my-consult-projectile--prompt prompt))
      (funcall 'consult-projectile (list (symbol-value source-sym)))))
  (defun my-consult-projectile-find-file ()
    "项目内找文件 (prompt: Find file:)."
    (interactive)
    (my-consult-projectile--run 'consult-projectile--source-projectile-file "Find file: "))
  (defun my-consult-projectile-recentf ()
    "项目 recentf."
    (interactive)
    (my-consult-projectile--run 'consult-projectile--source-projectile-recentf "Recent file: "))
  (defun my-consult-projectile-switch-to-buffer ()
    "项目 buffer."
    (interactive)
    (my-consult-projectile--run 'consult-projectile--source-projectile-buffer "Switch to buffer: "))
  (defun my-consult-projectile-find-dir ()
    "项目目录."
    (interactive)
    (my-consult-projectile--run 'consult-projectile--source-projectile-dir "Find directory: "))
  (defun my-consult-projectile-switch-project ()
    "切项目 (默认动作: 找文件, consult-projectile-use-projectile-switch-project 控制)."
    (interactive)
    (my-consult-projectile--run 'consult-projectile--source-projectile-project "Switch project: "))
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
;; ⚠️ 坑: corfu 激活后劫持 RET (corfu-insert), yes/no 确认框 (yes-or-no-p)
;; 输入 yes 后第一次回车被吃掉 → "要回车两次才确认" (2026-08 实测)。
;; 修复: advice 包住 yes-or-no-p/y-or-n-p, 确认期间临时关闭 corfu,
;; 不影响 M-x/文件选择等补全场景 (advice 不依赖 minibuffer 时序, 最可靠)。
(defun corfu-enable-in-minibuffer ()
  "Minibuffer 里也启用 corfu."
  (when (minibufferp)
    (corfu-mode 1)))
(add-hook 'minibuffer-setup-hook #'corfu-enable-in-minibuffer)

(defun my-corfu-disable-for-yesno (orig &rest args)
  "YES/NO 确认期间临时关闭 corfu (避免 RET 被 corfu-insert 劫持)."
  (let ((corfu-mode nil))
    (apply orig args)))
(advice-add 'yes-or-no-p :around #'my-corfu-disable-for-yesno)
(advice-add 'y-or-n-p :around #'my-corfu-disable-for-yesno)

;; savehist: 记录 minibuffer 历史, vertico 排序用
(use-package savehist
  :ensure nil
  :init
  (savehist-mode 1)
  :config
  ;; C-x d (dired) 的目录历史默认写在 file-name-history, 不在
  ;; savehist 默认保存列表 → 重启丢失。显式加入跨会话记录。
  (add-to-list 'savehist-additional-variables 'file-name-history))

(provide 'init-completion)
;;; init-completion.el ends here
