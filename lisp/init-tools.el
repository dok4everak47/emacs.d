;;; init-tools.el --- 开发工具 (which-key + magit + diff-hl) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; which-key: 按下前缀键 (如 C-c) 后弹出可用按键列表, 不用背快捷键
;; magit: Emacs 最好的 Git 客户端, C-x g 打开
;; diff-hl: 左侧 gutter 显示 git 变更标记 (新增/修改/删除)

;;; Code:

;; ---------- which-key: 按键提示面板 ----------
;; 按下 C-c / C-x / M-s 等前缀后, 短暂延迟弹出可用按键列表
(use-package which-key
  :ensure t
  :init
  (which-key-mode 1)
  :custom
  (which-key-idle-delay 0.5)               ; 0.5s 后弹出
  (which-key-max-description-length 40)
  (which-key-sort-order 'which-key-key-order-alpha)
  :config
  ;; 弹出位置: 底部
  (which-key-setup-side-window-bottom))

;; ---------- magit: Git 客户端 ----------
;; C-x g: 打开 magit status (主界面)
;; C-x M-g: 文件级 magit (只看当前文件)
(use-package magit
  :ensure t
  :bind
  (("C-x g" . magit-status)                ; 主界面
   ("C-x M-g" . magit-file-dispatch))      ; 文件级
  :custom
  (magit-diff-refine-hunk t)               ; diff 里按词高亮
  (magit-revision-show-gravatars nil))

;; ---------- diff-hl: git 变更标记 ----------
;; 左侧 gutter 显示 +/-/~ 标记, 实时更新
(use-package diff-hl
  :ensure t
  :init
  (global-diff-hl-mode 1)
  :config
  ;; 在左侧 fringe 也显示标记 (窄窗口时 gutter 不可见, fringe 仍可见)
  (diff-hl-margin-mode 1)
  ;; magit 操作后自动刷新
  (add-hook 'magit-post-refresh-hook #'diff-hl-magit-post-refresh))

;; ---------- diredfl: dired 文件类型高亮 ----------
;; 让 dired 按文件类型显示不同颜色, 不再全是黑白。
;; 自定义配色 (doom-one 主题色系, 覆盖 diredfl 默认):

;; ⚠️ macOS /bin/ls 是 BSD 版, 不认 GNU ls 的 --group-directories-first 等
;; 开关, C-x d 会报 "Listing directory failed but 'access-file' worked"。
;; 改用 ls-lisp (纯 elisp 实现), 不再 fork 外部 ls, 绕开所有 BSD/GNU 兼容坑。
(require 'ls-lisp)
(setq ls-lisp-use-insert-directory-program nil)
;;   目录=蓝  隐藏文件(.开头)=白  文档(.md/.txt)=暖黄  源码=绿
;;   图片=紫  压缩包=红  配置(.json/.yaml)=青
(use-package diredfl
  :ensure t
  :demand t
  :config
  (diredfl-global-mode 1)
  ;; 目录 → 蓝色
  (set-face-foreground 'diredfl-dir-name "#4A9EFF")

  ;; 自定义分类 face (defface + defvar 配套, 变量才能被 font-lock 引用)
  (defface my-dired-doc
    '((t (:foreground "#E5C07B"))) "dired: 文档类")
  (defvar my-dired-doc 'my-dired-doc)
  (defface my-dired-src
    '((t (:foreground "#98C379"))) "dired: 源码类(兜底)")
  (defvar my-dired-src 'my-dired-src)
  ;; 源码按语言细分 (doom-one 色板)
  (defface my-dired-py
    '((t (:foreground "#56B6C2"))) "dired: Python")
  (defvar my-dired-py 'my-dired-py)
  (defface my-dired-php
    '((t (:foreground "#C678DD"))) "dired: PHP")
  (defvar my-dired-php 'my-dired-php)
  (defface my-dired-cpp
    '((t (:foreground "#61AFEF"))) "dired: C/C++/C#")
  (defvar my-dired-cpp 'my-dired-cpp)
  (defface my-dired-js
    '((t (:foreground "#E5C07B"))) "dired: JS/TS")
  (defvar my-dired-js 'my-dired-js)
  (defface my-dired-go
    '((t (:foreground "#98C379"))) "dired: Go")
  (defvar my-dired-go 'my-dired-go)
  (defface my-dired-rs
    '((t (:foreground "#D19A66"))) "dired: Rust")
  (defvar my-dired-rs 'my-dired-rs)
  (defface my-dired-rb
    '((t (:foreground "#E06C75"))) "dired: Ruby")
  (defvar my-dired-rb 'my-dired-rb)
  (defface my-dired-java
    '((t (:foreground "#E06C75"))) "dired: Java")
  (defvar my-dired-java 'my-dired-java)
  (defface my-dired-sh
    '((t (:foreground "#98C379"))) "dired: Shell")
  (defvar my-dired-sh 'my-dired-sh)
  (defface my-dired-el
    '((t (:foreground "#C678DD"))) "dired: Emacs Lisp")
  (defvar my-dired-el 'my-dired-el)
  (defface my-dired-img
    '((t (:foreground "#C678DD"))) "dired: 图片类")
  (defvar my-dired-img 'my-dired-img)
  (defface my-dired-arc
    '((t (:foreground "#E06C75"))) "dired: 压缩包类")
  (defvar my-dired-arc 'my-dired-arc)
  (defface my-dired-cfg
    '((t (:foreground "#56B6C2"))) "dired: 配置文件类")
  (defvar my-dired-cfg 'my-dired-cfg)
  (defface my-dired-hidden
    '((t (:foreground "#ABB2BF"))) "dired: 隐藏文件")
  (defvar my-dired-hidden 'my-dired-hidden)

  ;; 按扩展名着色 (ANCHORED 挂在文件名起始处, override=t 覆盖 diredfl 默认)
  ;; 顺序: 文档→各语言源码→图片→压缩→配置→隐藏(最后, 覆盖前面的, 保证 .开头优先白)
  (font-lock-add-keywords
   'dired-mode
   `((,directory-listing-before-filename-regexp
      ("\\(.+\\)\\.\\(md\\|markdown\\|txt\\|org\\|rst\\|pdf\\)$"
       nil nil (0 my-dired-doc t))
      ;; 各语言源码
      ("\\(.+\\)\\.\\(py\\|pyw\\|pyx\\)$"
       nil nil (0 my-dired-py t))                                     ; Python → 青
      ("\\(.+\\)\\.\\(php\\|phtml\\)$"
       nil nil (0 my-dired-php t))                                    ; PHP → 紫
      ("\\(.+\\)\\.\\(c\\|h\\|cpp\\|hpp\\|cc\\|cxx\\|cs\\)$"
       nil nil (0 my-dired-cpp t))                                    ; C/C++/C# → 蓝
      ("\\(.+\\)\\.\\(js\\|jsx\\|mjs\\|ts\\|tsx\\)$"
       nil nil (0 my-dired-js t))                                     ; JS/TS → 黄
      ("\\(.+\\)\\.\\(go\\)$"
       nil nil (0 my-dired-go t))                                     ; Go → 绿
      ("\\(.+\\)\\.\\(rs\\)$"
       nil nil (0 my-dired-rs t))                                     ; Rust → 橙
      ("\\(.+\\)\\.\\(rb\\|rake\\|gemspec\\)$"
       nil nil (0 my-dired-rb t))                                     ; Ruby → 红
      ("\\(.+\\)\\.\\(java\\|kt\\|kts\\)$"
       nil nil (0 my-dired-java t))                                   ; Java/Kotlin → 红
      ("\\(.+\\)\\.\\(sh\\|bash\\|zsh\\|fish\\|ps1\\)$"
       nil nil (0 my-dired-sh t))                                     ; Shell → 绿
      ("\\(.+\\)\\.\\(el\\|elc\\)$"
       nil nil (0 my-dired-el t))                                     ; Elisp → 紫
      ;; 其余源码兜底 → 绿
      ("\\(.+\\)\\.\\(lua\\|pl\\|pm\\|swift\\|scala\\|clj\\|hs\\|ml\\|dart\\|ex\\|exs\\|erl\\|vim\\|sql\\)$"
       nil nil (0 my-dired-src t))
      ("\\(.+\\)\\.\\(png\\|jpg\\|jpeg\\|gif\\|webp\\|svg\\|ico\\)$"
       nil nil (0 my-dired-img t))
      ("\\(.+\\)\\.\\(zip\\|tar\\|gz\\|bz2\\|xz\\|7z\\|rar\\)$"
       nil nil (0 my-dired-arc t))
      ("\\(.+\\)\\.\\(json\\|yaml\\|yml\\|toml\\|ini\\|conf\\|env\\)$"
       nil nil (0 my-dired-cfg t))
      ;; 隐藏文件 (. 开头, 含 .DS_Store/.gitignore 等) → 白色, 最后匹配覆盖前面
      ("\\.[^ /]+$"
       nil nil (0 my-dired-hidden t))))
   t)) ; append: 排在 diredfl 规则之后, 后执行覆盖

;; ---------- dired-subtree: 目录树折叠 ----------
;; i 展开/折叠子树 (接管原生 insert-subdir, 更直观), TAB 在子目录间循环
;; 需先装 dired-subtree (MELPA)
(use-package dired-subtree
  :ensure t
  :after dired
  :demand t  ; dired 一加载立即执行本块 — 不加则 :config (C-x M-o/auto-revert) 会被 defer 到命令首次触发, 干净启动不生效
  :bind (:map dired-mode-map
         ("i" . dired-subtree-toggle)
         ("TAB" . dired-subtree-cycle))
  :config
  ;; C-x M-o: 切换显示/隐藏 dotfiles (dired-omit-mode, 原生功能)
  (define-key dired-mode-map (kbd "C-x M-o") #'dired-omit-mode)
  ;; 外部新建/删除文件后, 重进 dired 自动刷新列表, 不用手动 g
  (setq dired-auto-revert-buffer #'dired-directory-changed-p))

;; ---------- dired 查找/过滤 + 默认布局 (VSCode 风格) ----------
;; 1. 在 dired 里找文件 (全部内置, 零依赖):
;;    - C-s / C-r: 普通增量搜索整个列表
;;    - C-M-s / C-M-r: 只在"文件名"里搜索 (dired-isearch-filenames), 最常用
;;    - 回车确定后 C-x C-f 或 RET 打开
;; 2. 默认隐藏详情列 (权限/大小/日期): 列表只剩文件名, 干净如 VSCode 文件区。
;;    '(' 切换显示详情 (dired-hide-details-mode 内置 minor mode, 无包依赖)
(add-hook 'dired-mode-hook #'dired-hide-details-mode)

;; 3. 系统默认应用打开: 视频/PDF/图片/Office 文档不想进 Emacs 编辑的,
;;    C-c o 用系统默认 App 打开 (macOS → open, Linux → xdg-open)。
;;    自写函数避免引入 dired-open 包 + 依赖 xdg-open 可执行文件细节。
(defun my-dired-open-default-app ()
  "用系统默认应用打开当前行 (或被标记) 的文件.
macOS 用 `open', 其他平台用 `xdg-open'."
  (interactive)
  (let ((cmd (if (eq system-type 'darwin) "open" "xdg-open"))
        (files (dired-get-marked-files)))
    (if (null files)
        (user-error "没有可打开的文件")
      (dolist (f files)
        (start-process "default-app" nil cmd f)))))
(define-key dired-mode-map (kbd "C-c o") #'my-dired-open-default-app)

;; ---------- 窗口管理: 方向键切换 window ----------
;; windmove: Shift+方向键 切到对应方向的 window (rame 内多窗口时最直观)
;; C-x o 需要循环, 方向键一次到位
(windmove-default-keybindings)       ; Shift+方向键
(global-set-key (kbd "s-<up>") #'windmove-up)      ; ⌘+方向键 (macOS 风格, 不与 Shift 选区冲突)
(global-set-key (kbd "s-<down>") #'windmove-down)
(global-set-key (kbd "s-<left>") #'windmove-left)
(global-set-key (kbd "s-<right>") #'windmove-right)

;; ---------- 窗口大小: ⌘+方向键连续调 ----------
;; 在 window 内按 ⌘+方向键 切 window; 按 Shift+⌘+方向键 调当前 window 大小
;; 连续按 = 连续调, 比单步 C-x ^/{}/{ 快
(global-set-key (kbd "S-s-<up>") #'enlarge-window)       ; ⌘⇧↑ 当前 window 变高
(global-set-key (kbd "S-s-<down>") #'shrink-window)      ; ⌘⇧↓ 当前 window 变矮
(global-set-key (kbd "S-s-<left>") #'shrink-window-horizontally)  ; ⌘⇧← 变窄
(global-set-key (kbd "S-s-<right>") #'enlarge-window-horizontally) ; ⌘⇧→ 变宽
;; C-c w 弹出所有 window 候选 (buffer 名 + 维度), 模糊搜索选切
;; minibuffer 候选条目数 = 当前窗口数
;; 注: 不用 C-x w w — Emacs 30 的 C-x w 是 window keymap 前缀, 子键被占
(defun my-consult-window ()
  "用 consult 模糊搜索并切换到指定 window."
  (interactive)
  (let* ((wins (window-list nil nil (frame-first-window)))
         (candidates
          (mapcar (lambda (w)
                    (cons (format "%s  [%dx%d]"
                                   (buffer-name (window-buffer w))
                                   (window-total-width w)
                                   (window-total-height w))
                          w))
                  wins)))
    (if (= (length candidates) 1)
        (message "只有 1 个 window")
      (when-let ((selected (consult--read
                            (mapcar #'car candidates)
                            :prompt "切换到 window: "
                            :sort nil
                            :require-match t)))
        (select-window (alist-get selected candidates nil nil #'string=))))))

(define-key (current-global-map) (kbd "C-c w") #'my-consult-window)

(provide 'init-tools)
;;; init-tools.el ends here
