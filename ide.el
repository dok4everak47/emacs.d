;;; ide.el — VSCode 风格 IDE 外观层 -*- lexical-binding: t -*-
;;;
;;; 独立于邮件配置 (init.el)。不想要时: 删掉本文件 + init.el 末尾两行即可还原。
;;; 依赖: 网络可访问清华 ELPA 镜像 (首次加载自动安装缺失包)。
;;; 注意: 本文件不启用 native-comp (见 early-init.el), 包走字节码, 功能不受影响。

;; 编译期声明 (包/内置模块加载后变量才有定义)
(defvar display-line-numbers-type nil)
(defvar org-agenda-window-setup)   ; org 包的 defcustom, 声明为 special 供 let 动态绑定
(defvar org-agenda-sticky)
(declare-function dired-sidebar-toggle-sidebar "dired-sidebar")
(declare-function dired-sidebar-jump-to-sidebar "dired-sidebar")
(declare-function mood-line-mode "mood-line")
(declare-function dashboard-setup-startup-hook "dashboard")
(declare-function doom-themes-visual-bell-config "doom-themes")

;; ---------- 包管理: 内置 package.el + 清华镜像 ----------
(require 'package)
(setq package-archives
      '(("gnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
        ("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
        ("melpa" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))
(package-initialize)
(require 'use-package)
(setq use-package-always-ensure t)

;; ---------- 主题: One Dark (VSCode Dark+ 同款配色) ----------
(use-package doom-themes
  :config
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)
  (load-theme 'doom-one t)
  ;; 可视化错误提示 (闪屏替代蜂鸣声)
  (doom-themes-visual-bell-config))

;; ---------- 字体 (SpaceMono Nerd Font Mono: SpaceMono + Nerd 图标, Mono 变体保证等宽) ----------
(set-face-attribute 'default nil :family "SpaceMono Nerd Font Mono" :height 180)

;; 中文字体: 西文字体 (SpaceMono Nerd Font Mono) 没有中文字形, Emacs 会自动 fallback
;; 到系统默认中文字体, 导致中英文风格不统一。
;; 指定 fontset: 汉字/日文假名/谚文等 CJK 字符用苹方 (PingFang SC, macOS 内置)。
;; 想换其他中文字体, 改 "PingFang SC" 即可 (如 "Songti SC" 宋体 / "Heiti SC" 黑体)。
(dolist (charset '(kana han cjk-misc bopomofo))
  (set-fontset-font t charset (font-spec :family "PingFang SC")))

;; ---------- 标签页 (浏览器式: 每个 buffer 一个 tab, 点击切换) ----------
;; tab-bar-buffers: 把 tab-bar 的 tab 内容来源改成 buffer (每打开 buffer 一 tab,
;; 点 tab 切 buffer, 关 buffer 关 tab), 比 Emacs 默认的 tab (窗口布局快照) 直观。
;; ⚠️ tab-bar-buffers-mode 不会自动开 tab-bar-mode — 必须两个都开, 否则那一栏不显示。
(tab-bar-mode 1)
(tab-bar-buffers-mode 1)

;; ⚠️ tab-bar-buffers 默认按 buffer 名字母序排 tab → C-x 方向键跳转无规律。
;; 改成 buffer-list 顺序 (= 打开顺序, 最近激活的排最前), 切 tab 可预期。
(advice-add 'tab-bar-buffers--interesting-buffers--sort
            :override
            (lambda () (tab-bar-buffers--interesting-buffers)))

;; ⚠️ 排除 .org 文件 buffer 不进 tab-bar: 打开 agenda (C-c a) 时 org 会
;; 把 ~/org/ 下所有文件读进 buffer, tab-bar-buffers 每个 buffer 一个 tab,
;; 导致一堆 org 文件 tab。org 文件用 C-x b / dired 访问, 不需进 tab。
;; 用 :around advice 拦截 interesting-buffer-p, .org 一律 nil。
(defun my-tbb-hide-org-around (orig buffer)
  (if (and (bufferp buffer) (buffer-name buffer)
           (string-suffix-p ".org" (buffer-name buffer)))
      nil
    (funcall orig buffer)))
(advice-add 'tab-bar-buffers--interesting-buffer-p :around #'my-tbb-hide-org-around)

;; ---------- 窗口分屏方向 (Dired o / find-file-other-window 等) ----------
;; split-window-sensibly 规则: 窗口 >= split-width-threshold 字符宽 → 左右分;
;; 否则 >= split-height-threshold 行高 → 上下分; 都够不着且是唯一窗口 → 往下劈。
;; 默认 160 太宽, 普通帧永远左右不了, 只能上下堆叠。调到 90: 够宽就左右并排。
(setq split-width-threshold 90)

;; ---------- 侧边栏文件树 (dired-sidebar, VSCode 左侧 Explorer) ----------
;; dired-sidebar: 把 dired 放进侧边窗口, 天然继承 dired 全部键位 (i/TAB
;; 子树, C-x M-o dotfiles, g 刷新, wdired C-x C-q), 无需学新键。
;; 项目根检测走 projectile (dired-sidebar-project-root-fn 设为
;; dired-sidebar-project-root-projectile), projectile-after-switch-project-hook
;; 自动挂 → C-c p p 切项目 sidebar 自动刷新根目录。
;; meow: dired-sidebar-mode 继承 dired-mode → 已映射 motion 态, 无需配置。
;; ⚠️ 不用包自带的 dired-sidebar-project-root-projectile: 它在非项目 buffer
;; (dashboard/scratch) 里 projectile-project-root 返回 nil → expand-file-name
;; 报 "Wrong type argument: stringp, nil" (2026-08 实测 C-c t t 报错)。
;; 自定义 wrapper 兜底回退 default-directory。
(defun my-dired-sidebar-project-root ()
  "项目根: projectile 命中返回项目根; 否则回退当前目录 (防 nil 报错)."
  (or (when (fboundp 'projectile-project-root)
        (projectile-project-root))
      default-directory))
(use-package dired-sidebar
  :ensure t
  :demand t                                 ; :custom 变量需包加载才定义
  :after projectile                          ; 等 projectile 加载后配 root-fn
  :bind
  (;; 打开/收起侧边栏 (treemacs 同款 C-c t t)
   ("C-c t t" . dired-sidebar-toggle-sidebar)
   ;; 选中侧边栏窗口
   ("C-c t d" . dired-sidebar-jump-to-sidebar))
  :custom
  (dired-sidebar-width 28)
  (dired-sidebar-theme 'nerd-icons)         ; 文件图标 (nerd-icons 已装)
  (dired-sidebar-should-follow-file nil)    ; 不自动跟随 (流畅优先, 同 treemacs 教训)
  (dired-sidebar-refresh-on-project-switch t) ; 切项目时自动刷新根目录
  (dired-sidebar-close-sidebar-on-file-open nil) ; 打开文件后树保留
  (dired-sidebar-pop-to-sidebar-on-toggle-open nil) ; toggle 打开时不抢焦点
  (dired-sidebar-project-root-fn #'my-dired-sidebar-project-root)) ; 走 projectile (见下方)

;; ---------- dired 增强 (C-x d 原生 + C-x D 选目录) ----------
;; 双命令分工, 各司其职:
;; - C-x d: 原生 dired, 直接敲路径/补全进目录 — 符合肌肉记忆, 快速浏览。
;; - C-x D: consult-dir 弹候选选目录 (历史/项目/recentf/bookmark) 后进 dired —
;;   需要跳历史路径或项目根时用. 窄化: p=项目 r=recentf h=输入历史 .=当前.
(defun my-dired-choose ()
  "选择目录后打开 dired (候选含项目根/项目/历史/最近目录)."
  (interactive)
  (require 'consult-dir)
  (let ((consult-dir-default-command #'dired))
    (call-interactively #'consult-dir)))
(global-set-key (kbd "C-x D") #'my-dired-choose)

;; ---------- 文件图标 (nerd-icons-dired, dired-sidebar 依赖) ----------
(use-package nerd-icons-dired
  :ensure t
  :hook (dired-mode . nerd-icons-dired-mode))

;; ---------- projectile (项目管理, 替代内置 project.el) ----------
;; consult-projectile 提供 consult 风格候选 (vertico+orderless);
;; dired-sidebar 走 projectile 检测根目录 — 三者共享同一项目概念。
;; projectile-import-known-projects 自动从 project.el 已知项目迁移。
(use-package projectile
  :ensure t
  :demand t
  :custom
  (projectile-enable-caching t)              ; 大项目文件列表缓存
  (projectile-completion-system 'default)    ; 让 consult 接管候选 UI
  (projectile-show-menu nil)                 ; 隐藏菜单栏 Projectile 菜单 (只留快捷键)
  :config
  ;; 全局 minor mode 放 :config 而非 :init — 确保 :custom 先执行
  ;; (projectile-mode 启用时会读 projectile-completion-system)
  (projectile-mode 1)
  ;; 从内置 project.el 已知项目导入 (projectile 不会自动继承)
  (when (fboundp 'projectile-import-known-projects)
    (ignore-errors (projectile-import-known-projects))))

;; ---------- 状态栏 (VSCode 底部状态条: 文件名/修改/git/位置) ----------
(use-package mood-line
  :config
  (mood-line-mode 1))

;; ---------- 行号 (相对行号, evil-mode 最佳实践: 3j = 向下 3 行) ----------
(global-display-line-numbers-mode 1)
(setq display-line-numbers-type 'relative)

;; ---------- 隐藏工具条 (更像 VSCode; 需要时 M-x tool-bar-mode 可开回) ----------
(tool-bar-mode -1)

;; ---------- LSP (内置 eglot; PHP/Python/JS 自动启动, 其他语言手动) ----------
;; PHP: php-mode + phpactor (nix devShell)
;; Python: python-ts-mode + pyright; JS/TS: js-ts-mode + typescript-language-server
;; 说明: php-ts-mode (tree-sitter 版) 在 Emacs 30.2 要求 6 个 grammar
;; (php/phpdoc/html/js/jsdoc/css), 新版 tree-sitter-php 已合并 phpdoc/jsdoc,
;; 导致缺 grammar 拒绝启动, 故退回成熟的 php-mode。
;; js-ts-mode/python-ts-mode 是软检查 (when treesit-ready-p), 无此问题。
;; 其他语言 (eglot-ensure 找不到 server 会报错) 仍用 C-c e e 手动启动
(use-package eglot
  :bind (("C-c e e" . eglot))
  :config
  (setq eglot-autoshutdown t
        eglot-confirm-server-edits nil)
  ;; LSP server 注册 (eglot 默认不知道这些 server)
  (with-eval-after-load 'eglot
    (dolist (entry '((php-mode . ("phpactor" "language-server"))
                     (python-ts-mode . ("pyright" "language-server"))
                     (python-mode . ("pyright" "language-server"))
                     (js-ts-mode . ("typescript-language-server" "--stdio"))
                     (typescript-ts-mode . ("typescript-language-server" "--stdio"))))
      (add-to-list 'eglot-server-programs entry)))
  ;; 自动启动 eglot (LSP 只在 nix devShell 里, 找不到时 eglot-ensure 会提示)
  (add-hook 'php-mode-hook #'eglot-ensure)
  (add-hook 'python-ts-mode-hook #'eglot-ensure)
  (add-hook 'js-ts-mode-hook #'eglot-ensure)
  (add-hook 'typescript-ts-mode-hook #'eglot-ensure))

;; ---------- php-mode: PHP 语法高亮 + 缩进 ----------
(use-package php-mode
  :ensure t
  :mode ("\\.php\\'" "\\.phtml\\'"))

;; ---------- 菜单栏加 "IDE" 菜单 (GUI 友好, 不用记快捷键) ----------
(easy-menu-define nil global-map "IDE"
  '("IDE"
    ["文件树 (Explorer)" dired-sidebar-toggle-sidebar t]
    ["切换到文件树窗口" dired-sidebar-jump-to-sidebar t]
    ["刷新文件树" revert-buffer t]
    ["项目内找文件" my-consult-projectile-find-file t]
    ["切换项目" projectile-switch-project t]
    ["启动 LSP" eglot t]
    ["关闭 LSP" eglot-shutdown t]))

;; ---------- Dashboard 四模块卡片化 (svg-lib + :align-to 动态居中) ----------
(defconst my-dash-card-width 28 "Uniform content width in chars per card row.")
(defconst my-dash-card-rows 5 "Max content rows per card.")
(defconst my-dash-card-gap 4 "Horizontal gap between two cards, in cols.")

(defvar my-dash--cache nil
  "Cached dashboard data: (recents projects agenda bookmarks).")

(defun my-dash--trunc (str width)
  "Truncate STR to display WIDTH, CJK-aware."
  (let ((sw (string-width str)))
    (if (<= sw width) str
      (let ((pos 0) (w 0))
        (while (and (< w (- width 1)) (< pos (length str)))
          (setq w (+ w (char-width (aref str pos))))
          (setq pos (1+ pos)))
        (concat (substring str 0 pos) "…")))))

(defun my-dash--icon (icon)
  "Render Nerd Icon from full name like \"nf-md-folder\"."
  (unless (featurep 'nerd-icons)
    (require 'nerd-icons nil t))
  (let ((family (and (string-match "^nf-\\([a-z]+\\)-" icon)
                     (match-string 1 icon))))
    (cond
     ((string= family "fa")  (nerd-icons-faicon icon))
     ((string= family "md")  (nerd-icons-mdicon icon))
     ((string= family "oct") (nerd-icons-octicon icon))
     ((string= family "dev") (nerd-icons-devicon icon))
     ((string= family "cod") (nerd-icons-codicon icon))
     (t (nerd-icons-mdicon icon)))))

(defun my-dash--click-map (action)
  "Keymap for clickable tag.
ACTION is a Lisp form (eval'd) or a function (funcall'd)."
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET")
      (lambda (&rest _) (interactive)
        (if (functionp action) (funcall action) (eval action))))
    (define-key map [mouse-1]
      (lambda (&rest _) (interactive)
        (if (functionp action) (funcall action) (eval action))))
    (define-key map [mouse-2]
      (lambda (&rest _) (interactive)
        (if (functionp action) (funcall action) (eval action))))
    map))

(defun my-dash--align (spec)
  "Insert a space positioned by display :align-to SPEC (no space padding)."
  (insert (propertize " " 'display `(space :align-to ,spec))))

(defun my-dash--pad-right (str width)
  "Pad STR with spaces on the right to display WIDTH.
Spaces live inside the svg-lib image, not as buffer layout."
  (let ((sw (string-width str)))
    (if (>= sw width)
        str
      (concat str (make-string (- width sw) ?\s)))))

(defun my-dash--line-width (&rest _)
  "Box outer width (cols): content `my-dash-card-width' + 2 borders.
All card rows are padded to the same width, so cards are equal-sized."
  (+ my-dash-card-width 2))

(defun my-dash--card-width (icon label rows)
  "Actual width (cols) of a card = max(title, content rows)."
  (let ((w (my-dash--line-width icon label)))
    (dolist (r rows)
      (when r
        (setq w (max w (my-dash--line-width (nth 0 r) (nth 1 r))))))
    w))

(defun my-dash--box-fill ()
  "Horizontal box filler: ─ repeated to card content width."
  (make-string my-dash-card-width ?─))

(defun my-dash--box-top ()
  "Top border interior: ─×W (caller wraps with ┌ and ┐)."
  (my-dash--box-fill))

(defun my-dash--box-mid ()
  "Mid separator interior: ─×W (caller wraps with ├ and ┤)."
  (my-dash--box-fill))

(defun my-dash--box-bottom ()
  "Bottom border interior: ─×W (caller wraps with └ and ┘)."
  (my-dash--box-fill))

(defconst my-dash--box-border-face '(:foreground "#49505e")
  "Low-contrast gray-blue face for all box borders.")

(defun my-dash--box-row (text face &optional action)
  "Render one box row: gray │ border + padded content with FACE.
Content is padded to `my-dash-card-width' - 2 (one space each side),
so the whole row matches border width (`my-dash-card-width' + 2).
If ACTION given, only the CONTENT is clickable and highlighted —
the │ border stays gray on selection."
  (let* ((inner (- my-dash-card-width 2))
         (padded (my-dash--pad-right
                  (my-dash--trunc text inner)
                  inner)))
    (concat (propertize "│ " 'face my-dash--box-border-face)
            (if action
                (propertize padded
                            'face face
'keymap (my-dash--click-map action)
                             'mouse-face 'highlight
                             'help-echo (format "RET: %s" action))
              (propertize padded 'face face))
            (propertize " │" 'face my-dash--box-border-face))))

(defun my-dash--insert-card-row (text face &optional action)
  "Insert `my-dash--box-row' at current point."
  (insert (my-dash--box-row text face action)))

(defun my-dash--insert-card-pair (spec1 spec2)
  "Insert two boxed cards side by side, centered as one horizontal group.

SPEC is (ICON LABEL ROWS) where ROWS are (icon display action color).

Layout algorithm (dynamic, window-width independent, unchanged):
  w1/w2 = actual card widths; gap fixed; total = w1 + gap + w2.
  Each line's left card starts at `(- center (/ total 2))',
  right card at `(- center (/ total 2)) + w1 + gap'.
  `center' is a display-spec symbol resolved against the current
  window on every redisplay — no resize hook needed."
  (cl-destructuring-bind (icon1 label1 rows1) spec1
    (cl-destructuring-bind (icon2 label2 rows2) spec2
      (let* ((w1 (my-dash--card-width icon1 label1 rows1))
             (w2 (my-dash--card-width icon2 label2 rows2))
             (total (+ w1 my-dash-card-gap w2))
             (half (/ total 2))
             (col1 `(- center ,half))
             (col2 `(+ (- center ,half) ,(+ w1 my-dash-card-gap))))
        ;; ---- top border ----
        (my-dash--align col1)
        (insert (propertize (concat "┌" (my-dash--box-top) "┐") 'face my-dash--box-border-face))
        (my-dash--align col2)
        (insert (propertize (concat "┌" (my-dash--box-top) "┐") 'face my-dash--box-border-face))
        (insert "\n")
        ;; ---- title row ----
        (my-dash--align col1)
        (my-dash--insert-card-row
         (format "%s %s" (my-dash--icon icon1) label1) '(:foreground "#61afef"))
        (my-dash--align col2)
        (my-dash--insert-card-row
         (format "%s %s" (my-dash--icon icon2) label2) '(:foreground "#61afef"))
        (insert "\n")
        ;; ---- separator + content rows (height from actual data) ----
        (let ((rows-n (max (length rows1) (length rows2))))
          (when (> rows-n 0)
            (my-dash--align col1)
            (insert (propertize (concat "├" (my-dash--box-mid) "┤") 'face my-dash--box-border-face))
            (my-dash--align col2)
            (insert (propertize (concat "├" (my-dash--box-mid) "┤") 'face my-dash--box-border-face))
            (insert "\n"))
          (dotimes (i rows-n)
            (let ((r1 (nth i rows1))
                  (r2 (nth i rows2)))
              (my-dash--align col1)
              (when r1
                (my-dash--insert-card-row
                 (format "%s %s" (my-dash--icon (nth 0 r1)) (nth 1 r1))
                 `(:foreground ,(nth 3 r1)) (nth 2 r1)))
              (my-dash--align col2)
              (when r2
                (my-dash--insert-card-row
                 (format "%s %s" (my-dash--icon (nth 0 r2)) (nth 1 r2))
                 `(:foreground ,(nth 3 r2)) (nth 2 r2)))
              (insert "\n"))))
        ;; ---- bottom border ----
        (my-dash--align col1)
        (insert (propertize (concat "└" (my-dash--box-bottom) "┘") 'face my-dash--box-border-face))
        (my-dash--align col2)
        (insert (propertize (concat "└" (my-dash--box-bottom) "┘") 'face my-dash--box-border-face))
        (insert "\n\n")))))

;; ---------- Dashboard 数据源 (recents/projects/agenda/bookmarks) ----------
(defun my-dash--recents-data ()
  "Recent files as list of (NAME . PATH), existing files only."
  (mapcar (lambda (f)
            (cons (file-name-nondirectory (directory-file-name f)) f))
          (cl-remove-if (lambda (f)
                          (or (null f)
                              (string-match-p "^\\s-*$" f)
                              (not (file-exists-p f))))
                        (seq-take recentf-list 6))))

(defun my-dash--on-recentf-changed (&rest _)
  "Invalidate dashboard cache and re-render when recent files change.
Runs from `find-file-hook' / `kill-buffer-hook' so the Recent Files
card always reflects the latest activity."
  (when (and (boundp 'dashboard-buffer-name)
             (get-buffer dashboard-buffer-name))
    (setq my-dash--cache nil)
    (when (get-buffer-window dashboard-buffer-name)
      (with-current-buffer dashboard-buffer-name
        (dashboard-insert-startupify-lists t)))))
(add-hook 'find-file-hook #'my-dash--on-recentf-changed)
(add-hook 'kill-buffer-hook #'my-dash--on-recentf-changed)

(defun my-dash--projects-data ()
  "Projectile projects as list of (NAME . ROOT).
Filters out non-projects and bypasses projectile-project-name cache."
  (when (bound-and-true-p projectile-mode)
    (seq-mapcat
     (lambda (p)
       ;; Skip entries that aren't actual projects (e.g. no .git, no marker)
       (when (projectile-project-p p)
         (list (cons (projectile-default-project-name p) p))))
     (seq-take (projectile-relevant-known-projects) 20))))

(defun my-dash--bookmarks-data ()
  "Bookmarks as list of (NAME . LOCATION)."
  (require 'bookmark)
  (bookmark-maybe-load-default-file)
  (when (and (boundp 'bookmark-alist) bookmark-alist)
    (mapcar (lambda (bm)
              (let ((name (bookmark-name-from-full-record bm)))
                (cons name (or (bookmark-location bm) ""))))
            (seq-take bookmark-alist 5))))

;; ---------- Agenda 卡片异步加载 (2026-08-14) ----------
;; 启动阻塞根因: dashboard-insert-startupify-lists 挂在 after-init-hook,
;; 而 Agenda 卡片的 my-dash--agenda-data 会同步执行 (org-agenda nil "a"),
;; 逐个 find-file-noselect 打开全部 agenda 文件 (实测每个 ~1.9s, 6 个文件
;; 共 ~11.7s), 导致 Dashboard 十几秒后才出现。
;; (表象是 "Loading gcal-client.el...done" 之后卡住 — gcal-client.el 只是
;; 两个 setq, 毫秒级, 无辜; 卡的是它之后 after-init-hook 里的 agenda 计算。)
;; 修复: agenda 计算移到子进程 (emacs --quick + agenda-dump.el, ~1s),
;; 主 Emacs 全程可交互; 卡片先显示 "Loading calendar…" 占位, 子进程
;; 完成后 sentinel 重渲染填入。计算逻辑在 agenda-dump.el, agenda 文件
;; 列表由这里实时传入 (改 org-agenda-files 自动生效, 不复制配置)。
(defvar my-dash--agenda-rows nil
  "Agenda rows for the dashboard card, computed asynchronously once per session.")

(defvar my-dash--agenda-loading nil
  "Non-nil while the async agenda computation is pending/running.")

(defvar my-dash--agenda-watchdog nil
  "Watchdog timer: clears `my-dash--agenda-loading' if the subprocess hangs.")

(defvar my-dash--agenda-refreshed nil
  "Non-nil once the background subprocess refreshed the agenda this session.")

(defun my-dash--agenda-cache-load ()
  "Load agenda rows from the cache file (instant, previous session's data).
缓存让启动时卡片秒显, 后台子进程随后刷新 (见 `my-dash--agenda-load-async')。
缓存文件在 ~/.emacs.d/cache/ (已 gitignore)。"
  (let ((cache (expand-file-name "cache/agenda-cache.el" user-emacs-directory)))
    (when (and (not my-dash--agenda-rows) (file-exists-p cache))
      (condition-case nil
          (let ((data (with-temp-buffer
                        (insert-file-contents cache)
                        (read (current-buffer)))))
            (when (consp data)
              (setq my-dash--agenda-rows data)))
        (error nil)))))

(defun my-dash--agenda-load-async ()
  "Compute agenda data in a background --quick Emacs subprocess (~1s).
org-agenda 在 GUI 里逐个打开 agenda 文件很慢 (实测 ~2s/文件) — 同步计算
会冻结主界面。策略:
  1) 有缓存文件 → 立即显示 (昨天的数据, 无 Loading 占位)
  2) 每会话派一次子进程 (emacs --quick --batch + agenda-dump.el, ~1s)
     刷新数据, sentinel 完成后更新卡片并重写缓存"
  (unless my-dash--agenda-loading
    (my-dash--agenda-cache-load)
    (unless my-dash--agenda-refreshed
      (setq my-dash--agenda-loading t)
      (let ((emacs (executable-find "emacs"))
            (script (expand-file-name "agenda-dump.el" user-emacs-directory))
            (out "/tmp/my-dash-agenda.out"))
        (if (not emacs)
            (progn (setq my-dash--agenda-loading nil)
                   (my-dash--rerender))
          (delete-file out t)
          (let ((files (mapconcat (lambda (f) (format "%S" (expand-file-name f)))
                                  org-agenda-files " ")))
            (make-process
             :name "my-dash-agenda"
             :buffer (generate-new-buffer " *my-dash-agenda*")
             :command
             (list emacs "--quick" "--batch"
                   "-l" script
                   "--eval"
                   (format "(my-agenda-dump (quote (%s)) %S)" files out))
             :sentinel #'my-dash--agenda-sentinel)))
          ;; 看门狗: 子进程异常挂死 (如卡在某个提示) 时, 15s 后清除 loading,
          ;; 卡片不再显示 "Loading…" (有缓存时本来就显示缓存数据)。
          (setq my-dash--agenda-watchdog
                (run-at-time 15 nil
                             (lambda ()
                               (when my-dash--agenda-loading
                                 (setq my-dash--agenda-loading nil)
                                 (my-dash--rerender)))))))))

(defun my-dash--agenda-sentinel (proc _event)
  "Subprocess finished: read the result sexp, update cache and re-render."
  (when (memq (process-status proc) '(exit signal))
    (when my-dash--agenda-watchdog
      (cancel-timer my-dash--agenda-watchdog)
      (setq my-dash--agenda-watchdog nil))
    (let ((ok (eq (process-exit-status proc) 0))
          (out "/tmp/my-dash-agenda.out"))
      (when (buffer-live-p (process-buffer proc))
        (kill-buffer (process-buffer proc)))
      (setq my-dash--agenda-loading nil)
      (setq my-dash--agenda-refreshed t)
      (let ((data (and ok
                       (file-exists-p out)
                       (condition-case nil
                           (with-temp-buffer
                             (insert-file-contents out)
                             (read (current-buffer)))
                         (error nil)))))
        (when (consp data)
          (setq my-dash--agenda-rows data)
          ;; 写缓存: 下次启动秒显 (cache/ 已 gitignore)
          (condition-case nil
              (with-temp-file
                  (expand-file-name "cache/agenda-cache.el" user-emacs-directory)
                (insert (prin1-to-string data)))
            (error nil))))
      ;; 重建 cache (agenda 槽换新数据) — 直接 rerender 会用启动时的
      ;; 旧 cache (agenda 槽 nil), 卡片停留在占位/不可用状态 (2026-08-14)。
      ;; refresh-cache 内部的 agenda-load-async 有 rows 非 nil 守卫, 不会重复派生。
      (my-dash--refresh-cache)
      ;; 无论成败都重渲染, 把 \"Loading…\" 换成数据或空状态文案
      (my-dash--rerender))))

(defun my-dash--rerender ()
  "Re-render the dashboard buffer if it exists and is visible."
  (when (and (boundp 'dashboard-buffer-name)
             (get-buffer dashboard-buffer-name)
             (get-buffer-window dashboard-buffer-name))
    (with-current-buffer (get-buffer dashboard-buffer-name)
      (dashboard-insert-startupify-lists t))))

(defun my-dash--refresh-cache ()
  "Fill `my-dash--cache' from data sources.
Agenda comes from `my-dash--agenda-rows' (loaded asynchronously once,
see `my-dash--agenda-load-async'), so startup never blocks on org-agenda."
  (setq my-dash--cache
        (list (my-dash--recents-data)
              (my-dash--projects-data)
              my-dash--agenda-rows
              (my-dash--bookmarks-data)))
  (my-dash--agenda-load-async))

(defun my-dash-insert-items ()
  "Render 2×2 card grid: recents/projects/agenda/bookmarks."
  (unless my-dash--cache
    (my-dash--refresh-cache))
  (let ((recents (nth 0 my-dash--cache))
        (projects (nth 1 my-dash--cache))
        (agenda (nth 2 my-dash--cache))
        (bookmarks (nth 3 my-dash--cache)))
    (my-dash--insert-card-pair
     (list "nf-fa-files_o" "Recent Files"
           (mapcar (lambda (f)
                     (list "nf-md-file" (car f) (list 'find-file-existing (cdr f)) "#98be65"))
                   (seq-take recents my-dash-card-rows)))
     (list "nf-fa-folder_open_o" "Projects"
           (mapcar (lambda (p)
                     (list "nf-md-folder" (car p) (list 'projectile-switch-project-by-name (cdr p)) "#c678dd"))
                   (seq-take projects my-dash-card-rows))))
    (my-dash--insert-card-pair
     (list "nf-fa-calendar" "Agenda"
           (if agenda
               (mapcar (lambda (a)
                         (list "nf-md-calendar_clock" (car a) '(org-agenda nil "a") "#e5c07b"))
                       (seq-take agenda my-dash-card-rows))
             ;; agenda 异步加载中/失败: 先显示占位, 数据到了自动重渲染
             (list (list "nf-md-calendar_clock"
                         (if my-dash--agenda-loading
                             "Loading calendar…"
                           "Agenda unavailable")
                         nil "#5b6268"))))
     (list "nf-fa-bookmark_o" "Bookmarks"
           (mapcar (lambda (b)
                     (list "nf-md-bookmark" (car b)
                           (list 'bookmark-jump (car b)) "#56b6c2"))
                   (seq-take bookmarks my-dash-card-rows))))))

(defun my-dash--navigator-row (row)
  "Render one navigator ROW as clickable buttons, joined by gap spaces.
Buttons keep `dashboard-navigator-buttons' (icon label help action).
The icon is NOT re-propertized (its nerd-icons :family face must
survive so the glyph stays 1 column); only the label gets the
bright-blue color. Both icon and label are clickable."
  (mapconcat
   (lambda (btn)
     (let* ((icon (nth 0 btn))
            (label (nth 1 btn))
            (action (nth 3 btn))
            (click-props (list 'keymap (my-dash--click-map action)
                               'mouse-face 'highlight
                               'help-echo (nth 2 btn))))
       (concat (apply #'propertize icon click-props)
               (apply #'propertize (concat " " label)
                      (append click-props
                              (list 'face '(:foreground "#7aa2f7")))))))
   row (make-string my-dash-card-gap ?\s)))

(defun my-dash-insert-navigator-box ()
  "Render `dashboard-navigator-buttons' inside one centered box.
Box width = widest button row + 4 (│ + space + content + space + │).
Top `┐', content `│' and bottom `┘' are all placed via `:align-to'
at the same right column, so they always line up regardless of any
glyph width estimation error."
  (let* ((raw-rows (mapcar #'my-dash--navigator-row dashboard-navigator-buttons))
         (content-w (apply #'max (mapcar #'string-width raw-rows)))
         (box-w (+ content-w 4))
         (half (/ box-w 2))
         (col `(- center ,half))
         (right `(+ (- center ,half) ,(1- box-w))))
    (my-dash--align col)
    (insert (propertize (concat "┌" (make-string (+ content-w 2) ?─))
                        'face my-dash--box-border-face))
    (my-dash--align right)
    (insert (propertize "┐" 'face my-dash--box-border-face))
    (insert "\n")
    (dolist (row raw-rows)
      (my-dash--align col)
      (insert (propertize "│ " 'face my-dash--box-border-face))
      (insert row)
      (my-dash--align right)
      (insert (propertize "│" 'face my-dash--box-border-face))
      (insert "\n"))
    (my-dash--align col)
    (insert (propertize (concat "└" (make-string (+ content-w 2) ?─))
                        'face my-dash--box-border-face))
    (my-dash--align right)
    (insert (propertize "┘" 'face my-dash--box-border-face))
    (insert "\n")))

;; ---------- Dashboard 导航页 (emacs-dashboard 包, 参考 condy0919) ----------
;; C-c h 随时回到 Dashboard (home)
(global-set-key (kbd "C-c h") #'dashboard-open)
(use-package nerd-icons
  :ensure t
  :when (display-graphic-p)
  :demand t)

(use-package dashboard
  :ensure t
  :init
  ;; Navigator 按钮分两行: 第一行 = 邮件 + IDE, 第二行 = 人生管理 (org)
  ;; (fboundp 守卫: nerd-icons 未加载时回退到文字图标)
  (setq dashboard-navigator-buttons
        `(((,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-mail") "✉")
            "收邮件" "Gnus 收邮件"
            (lambda (&rest _) (gnus)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-pencil") "✍")
            "Gmail" "撰写 Gmail"
            (lambda (&rest _) (my-compose-gmail)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-paper_airplane") "✈")
            "126" "撰写 126 邮件"
            (lambda (&rest _) (my-compose-mail126)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-file_directory") "📂")
            "文件树" "打开 dired-sidebar 侧边栏"
            (lambda (&rest _) (dired-sidebar-toggle-sidebar)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-sign_out") "🚪")
            "退出" "退出 Emacs"
            (lambda (&rest _) (save-buffers-kill-terminal))))
          ;; 第二行: 人生管理 (org)
          ((,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-calendar") "📅")
            "日程" "人生管理主视图: 本周日程 + 待办"
            (lambda (&rest _) (org-agenda nil "n")))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-plus") "✚")
            "捕获" "快速捕获任务/笔记 (C-c c)"
            (lambda (&rest _) (org-capture)))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-inbox") "📥")
            "收件箱" "打开收集箱 inbox.org"
            (lambda (&rest _) (find-file "~/org/inbox.org")))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-repo") "🗂")
            "项目" "打开项目树 projects.org"
            (lambda (&rest _) (find-file "~/org/projects.org")))
           (,(if (fboundp 'nerd-icons-octicon)
                 (nerd-icons-octicon "nf-oct-book") "📔")
            "日记" "打开日记 journal.org"
            (lambda (&rest _) (find-file "~/org/journal.org"))))))
  (dashboard-setup-startup-hook)
  :custom
  (dashboard-startup-banner 'logo)
  (dashboard-set-heading-icons t)
  (dashboard-set-file-icons t)
  (dashboard-center-content t)
  (dashboard-vertically-center-content t)
  (dashboard-banner-logo-title "Welcome to Emacs")
  ;; 四模块: recents/projects/agenda/bookmarks (卡片化渲染, 见 my-dash-insert-items)
  (dashboard-items '((recents . 6)
                     (projects . 5)
                     (agenda . 5)
                     (bookmarks . 5)))
  (dashboard-projects-backend 'projectile)
  ;; 最近文件路径太长 → 截断开头 (只留文件名附近), 最大 40 字符
  (dashboard-path-style 'truncate-beginning)
  (dashboard-path-max-length 40)
  ;; footer 固定文案 (默认是随机英文梗语录), 带 Emacs 版本号
  (dashboard-footer-messages
   (list (format "Happy hacking! · Emacs %s" emacs-version)))
  (dashboard-startupify-list
   '(dashboard-insert-banner
     dashboard-insert-newline
     dashboard-insert-banner-title
     dashboard-insert-newline
     my-dash-insert-navigator-box
     dashboard-insert-newline
     dashboard-insert-init-info
     dashboard-insert-newline
     my-dash-insert-items
     dashboard-insert-newline
     dashboard-insert-footer))
  :custom-face
  ;; 标题放大加粗 (默认 inherit default)
  (dashboard-banner-logo-title ((t (:height 2.0 :weight bold))))
  ;; footer 亮灰斜体 (默认继承 widget-button, 颜色偏暗)
  (dashboard-footer-face ((t (:foreground "#aaaaaa" :slant italic)))))

;; 最近文件记录 (dashboard recents 依赖)
(recentf-mode 1)

;; tab-bar-tab-name-format: 用默认 (tab-bar-buffers 自带文件名显示)
;; 不再自定义 🏠 Home — 那段返回纯字符串无 text properties,
;; 导致 tab-bar-buffers 渲染整个 tab 列表为空 (tab 不显示)。

(provide 'ide)
;;; ide.el ends here
