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
;; 轻量, 基于 child frame, 消费 LSP (lsp-mode/eglot) 的 CAPF 补全。
;; CAPF 顺序由 lsp-completion-mode/eglot 自动注册, cape 在后兜底。
(use-package corfu
  :ensure t
  :init
  (global-corfu-mode 1)
  :custom
  (corfu-auto t)                           ; 自动弹出
  (corfu-auto-delay 0.1)                   ; 短延迟, 避开 LSP 网络抖动
  (corfu-auto-prefix 1)                    ; 1 字符即触发 (支持 obj. 点访问)
  (corfu-cycle t)                          ; 候选循环
  (corfu-quit-no-match 'separator)         ; 无匹配按分隔符收菜单
  (corfu-preview-current t)                ; 候选文档预览
  (corfu-preselect 'prompt)                ; 默认选中首项
  (corfu-on-exact-match nil)               ; 完全匹配也保留菜单, 方便看同名词
  :config
  ;; Tab 接受补全
  (define-key corfu-map (kbd "TAB") #'corfu-insert)
  (define-key corfu-map (kbd "<tab>") #'corfu-insert)
  ;; RET 不抢 (避免误提交, LSP 自动补全时常用 Tab 接受)
  (define-key corfu-map (kbd "<return>") nil)

  ;; ---- 智能增强 (均为 corfu 自带扩展, 无需额外装包) ----
  ;; 1) 候选文档预览: corfu-echo 在底部 echo 区显示当前候选的签名/文档,
  ;;    → 接近 VS Code 的"列表+文档"观感, 但不弹第二个框 (popupinfo 会弹独立
  ;;    子窗 = 用户不想要的"两个框", 已弃用)。
  (corfu-echo-mode 1)
  (setq corfu-echo-delay '(0.5 . 1.0))   ; 选中候选后 0.5s 显示文档, 停留 1s
  ;; 2) 按使用历史排序候选 (常选的靠前), 越用越贴合个人习惯。
  ;;    历史随 savehist 持久化 (corfu-history 自动加入 savehist 变量)。
  (corfu-history-mode 1)
  ;; 3) 候选前显示数字索引, M-1..M-9 直接插入对应项 (手不用离开主键区选)
  (corfu-indexed-mode 1))

;; ---------- 补全候选类型图标 (nerd-icons-corfu) ----------
;; 依赖 nerd-icons (ide.el 已装, dashboard/dired 在用)。在 corfu 候选左侧
;; margin 渲染类型图标: ƒ 函数 / 𝘢 变量 / ⬡ 属性 / 📦 模块 / ▤ 类 / 🜲 接口…
;; 数据来源是 LSP 注释里带的 :company-kind (tsserver 的 LSP CompletionItem
;; kind, lsp-mode/eglot 都会翻译成 function/method/module/property 等符号)。
;; cape 等本地兜底无 kind 时显示 ? (可接受, 兜底场景本来就没语义信息)。
;; ⚠️ corfu 2.x 不用 minor mode, 只需把 formatter 加进 corfu-margin-formatters
;; 变量 (corfu--affixate 渲染 margin 时跑 hook); 旧教程里的
;; nerd-icons-corfu-mode 已不存在, 照旧教程写会 void-function。
(use-package nerd-icons-corfu
  :ensure t
  :after corfu
  :config
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))

;; ---------- 终端 (-nw) 下的 corfu 弹窗提示 ----------
;; corfu 浮窗依赖 child frame, 纯终端不支持 (corfu--popup-support-p 为 nil):
;; 打字自动弹出 (corfu-auto) 不会触发, 手动补全也退回内置 *Completions* 列表。
;; 这是设计行为, 不是配置坏了 (2026-08-17 诊断确认)。
;; 终端里要浮窗需装 tty-child-frames (GitHub 源码包, 非 ELPA, 且依赖终端兼容性)。
(when (not (display-graphic-p))
  (defvar my-corfu-tty-warned nil
    "终端会话内是否已提示过 corfu 浮窗不可用 (每个会话只提示一次).")
  (defun my-corfu-tty-warn ()
    "打开编程文件时提示一次: 终端下 corfu 浮窗不可用."
    (unless my-corfu-tty-warned
      (setq my-corfu-tty-warned t)
      (message "提示: 终端模式下 corfu 补全浮窗不可用 (需 child frame)。写代码建议用 GUI Emacs; 终端内可试试 TAB 看内置候选列表。")))
  (add-hook 'prog-mode-hook #'my-corfu-tty-warn))

;; ---------- yasnippet 语句模板补全 (VS Code 式 snippet) ----------
;; 输入触发词 (try / cl / forof / exp / fn ...) 时, 补全列表出现可一键展开的
;; 语句模板 (与 VS Code 内置 snippets 同款)。语言文件夹: ~/.emacs.d/snippets/
;; (js-ts-mode 已建 15 个高频模板, tsx/typescript-ts-mode 用符号链接共享)。
;;
;; 与 lsp 补全共存设计 (corfu 每次只消费一个 CAPF 源):
;;   - my-capf-yasnippet 返回 :exclusive 'no 且排在 lsp 之前
;;   - 命中 snippet 触发词 → 只弹模板 (VS Code 输入 try/cl 同样优先 snippet);
;;   - 没有匹配 → 返回 nil, lsp-completion-at-point 正常接管语义补全。
;; 因此需要 lsp 连接后把 yasnippet 重新提到最前 (lsp-completion-mode 会用
;; add-to-list 把 lsp-completion-at-point 放到列表头部)。

(defvar my-capf-yas--loaded nil
  "my-capf-yasnippet 首次调用是否已完成过一次 yas-reload-all.")

(defun my-capf-yasnippet ()
  "yasnippet 片段补全: key 前缀匹配当前 mode 的 snippet 表, 选中即展开语句模板."
  (when (and (bound-and-true-p yas-minor-mode)
             (fboundp 'yas--get-snippet-tables))
    ;; 首次调用时全量加载 snippet 表 (yas-reload-all t = no-jit, 同步建表;
    ;; 默认 JIT 在批量环境下可能不触发, 导致表为空)
    (unless my-capf-yas--loaded
      (yas-reload-all t)
      (setq my-capf-yas--loaded t))
    (let* ((tables (delq nil (mapcar (lambda (m) (gethash m yas--tables))
                                     (yas--modes-to-activate))))
           (beg (save-excursion (skip-syntax-backward "w_") (point)))
           (prefix (buffer-substring-no-properties beg (point)))
           ;; ⚠️ yas--table-hash 的结构是 KEY → NAMEHASH(name→template) 两层!
           ;; 不能直接拿 value 当 template。用官方 API yas--fetch 取 (NAME . TEMPLATE)
           ;; 列表, 构建 (key . template) 的 alist (之前把 NAMEHASH 当 template 传给
           ;; yas--template-content 会 wrong-type-argument → Tab 展开失败)。
           (alist (cl-loop for table in tables
                           append (cl-loop for key being the hash-keys of (yas--table-hash table)
                                           when (and (stringp key)
                                                     (string-prefix-p prefix key))
                                           for nt = (car (yas--fetch table key))
                                           when nt
                                           collect (cons key (cdr nt))))))
      (when alist
        (list beg (point)
              (lambda (probe pred action)
                (complete-with-action action (mapcar #'car alist) probe pred))
              :annotation-function
              (lambda (cand)
                (let ((tpl (cdr (assoc cand alist))))
                  (when tpl
                    (concat "  " (propertize (or (yas--template-name tpl) "")
                                              'face 'font-lock-comment-face)))))
              :exit-function
              (lambda (cand _status)
                (let ((tpl (cdr (assoc cand alist))))
                  (when tpl
                    ;; 删除已输入的触发词 (key), 再展开模板真身
                    (delete-region beg (point))
                    (yas-expand-snippet (yas--template-content tpl))))))))))

;; lsp 连接后 (lsp-completion-mode 开启, lsp 被 add-to-list 到头部) 重排:
;; 把 my-capf-yasnippet 提到 lsp 之前, 保证 snippet 触发词优先
(defun my-capf-yasnippet-prioritize ()
  "lsp-completion-mode 开启后把 yasnippet CAPF 提到 lsp 之前."
  (when (and (bound-and-true-p yas-minor-mode)
             (member 'lsp-completion-at-point completion-at-point-functions))
    (setq-local completion-at-point-functions
                (cons 'my-capf-yasnippet
                      (delq 'my-capf-yasnippet
                            completion-at-point-functions)))))
(add-hook 'lsp-completion-mode-hook #'my-capf-yasnippet-prioritize)

;; cape: corfu 的额外补全后端 (dictionary/abbrev/file/dabbrev)
;; ⚠️ 坑: 不能用 (add-to-list 'completion-at-point-functions ...)!
;; 配置加载时 current-buffer 是 *scratch* (emacs-lisp-mode), 它的
;; completion-at-point-functions 是 buffer-local 的 → add-to-list 会把
;; cape 写进 *scratch* 的局部值, 默认值 (所有普通文件用的) 永远没有,
;; 兜底 100% 失效 (2026-08-17 实测)。必须显式写 default-value, 且放在
;; :init (启动即执行), 不能放 :config (等包加载, 可能永不执行)。
(use-package cape
  :ensure t
  :init
  ;; cape-dict/cape-file/cape-dabbrev 依次压进默认 CAPF 最前 (tags 兜底在后)
  (dolist (fn '(cape-dabbrev cape-file cape-dict))
    (unless (member fn (default-value 'completion-at-point-functions))
      (setq-default completion-at-point-functions
                    (cons fn (default-value 'completion-at-point-functions)))))
  ;; 额外智能后端 (均 autoload, 仅符号入列不强制加载):
  ;;  - cape-keyword: 当前 major-mode 的语言关键字 (if/function/const...)
  ;;  - cape-history: 本会话/本文件输入过的词组 (重复输入更快)
  (dolist (fn '(cape-keyword cape-history))
    (unless (member fn (default-value 'completion-at-point-functions))
      (setq-default completion-at-point-functions
                    (append (default-value 'completion-at-point-functions) (list fn))))))

;; ⚠️ 必须放在 cape 段之后执行: 两段都用 cons 前插, 后执行者排最前。
;; yasnippet 段若在 cape 段前, cape-dict/file/dabbrev 会反超到最前 →
;; LSP 未连接时触发词被 cape 先截走 ("TS 触发词失效" bug 根因, 2026-08 实测)。
;; 这里把 my-capf-yasnippet 提到 cape 三兄弟之前 (无 LSP 场景也能用)。
(dolist (fn '(my-capf-yasnippet))
  (unless (member fn (default-value 'completion-at-point-functions))
    (setq-default completion-at-point-functions
                  (cons fn (default-value 'completion-at-point-functions)))))

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
