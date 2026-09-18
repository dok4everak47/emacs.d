;;; init-dev.el --- 开发辅助 (flymake 语法检查 + live preview) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; flymake: Emacs 29+ 内置的实时语法检查 (替代 flycheck)
;;   - 编辑时自动在 fringe 显示错误/警告标记
;;   - M-g n / M-g p 在错误间跳转, C-c ! l 打开错误列表
;;
;; impatient-mode: HTML/CSS 实时预览 (替代 VSCode Live Server)
;;   - 编辑 HTML/CSS 时在浏览器实时更新
;;   - M-x impatient-mode 开启, 浏览器访问 http://localhost:8080/impulsive

;;; Code:

;; ---------- 括号自动配对 (VS Code 式: 输入 ( 自动补 ) ----------
;; electric-pair-mode 是全局 minor mode, 输入左括号自动插入右括号并保持光标在中间
;; 编程和 org 笔记都适用; 不想在字符串/注释里配对的场景由 electric-pair-inhibit 处理
(electric-pair-mode 1)

;; ---------- flymake: 实时语法检查 ----------
;; Emacs 29+ 内置, 不需要额外安装包
;; 配合 lsp-mode (已在 ide.el 中配置) 使用时, LSP 诊断自动走 flymake
;; (lsp-diagnostics-provider 设为 :flymake)
(use-package flymake
  :ensure nil                                 ; 内置包, 不从 ELPA 安装
  :bind
  (:map flymake-mode-map
        ("M-g n" . flymake-goto-next-error)   ; 下一个错误
        ("M-g p" . flymake-goto-prev-error)   ; 上一个错误
        ("C-c ! l" . flymake-show-buffer-diagnostics)) ; 错误列表
  :custom
  (flymake-fringe-indicator-position 'left-fringe) ; 左侧 fringe 显示标记
  (flymake-margin-indicator-position 'left-margin) ; margin 也显示标记 (非 nil 即启用, 无 flymake-margin-enabled 变量)
  :config
  ;; 编程语言 major-mode 启动时自动开 flymake
  ;; (lsp-mode 启动时会自动启用 flymake, 这里兜底非 LSP 场景)
  (add-hook 'prog-mode-hook #'flymake-mode))

;; ---------- flymake 错误列表美化 ----------
;; flymake-show-buffer-diagnostics 弹出的列表默认样式简陋,
;; 用 consult 集成后可以模糊搜索 + 预览跳转
;; 坑: 必须嵌套 with-eval-after-load — 只守卫 fboundp 不够,
;; flymake-mode-map 在 flymake 未加载时是 void-variable (2026-08 实测炸过)
(with-eval-after-load 'consult
  (when (fboundp 'consult-flymake)
    (with-eval-after-load 'flymake
      (define-key flymake-mode-map (kbd "C-c ! f") #'consult-flymake))))

;; ---------- impatient-mode: HTML/CSS 实时预览 ----------
;; 编辑 HTML/CSS 时在浏览器实时刷新 (类似 VSCode Live Server)
;; 用法: 编辑 HTML/CSS 时按 C-c C-b 一键开预览, 浏览器自动打开
;; 保存即刷新, 不需要手动 reload
(use-package impatient-mode
  :ensure t
  :commands (impatient-mode)
  :custom
  (impatient-mode-delay 0.5)               ; 0.5s 防抖 (变量名 impatient-mode-delay)
  :config
  ;; impatient 需要 simple-httpd, 懒启动 (首次开 impatient-mode 时才起)
  (use-package simple-httpd
    :ensure t
    :custom
    (httpd-port 8080)
    (httpd-host "localhost"))
  ;; impatient-mode 开启时自动启动 httpd (而不是每次启动 Emacs 都开)
  (advice-add 'impatient-mode :before
              (lambda (&rest _)
                (unless (fboundp 'httpd-running-p)
                  (require 'simple-httpd))
                (when (fboundp 'httpd-running-p)
                  (unless (httpd-running-p)
                    (httpd-start))))))

;; --- 一键预览: C-c C-p 开 impatient + 浏览器自动打开 ---
;; 函数和键绑定放顶层 (不在 use-package :config 里),
;; 否则 :commands 懒加载导致 C-c C-p 要等首次 M-x impatient-mode 才注册。
(defun my-impatient-preview ()
  "一键开 HTML/CSS 实时预览: 开 impatient-mode + 浏览器打开预览页.
再按一次关闭预览 (impatient-mode toggle).
C-c <letter> 是用户保留键, 不会与 major-mode 冲突."
  (interactive)
  (if (bound-and-true-p impatient-mode)
      ;; 已开 → 关闭
      (progn
        (impatient-mode -1)
        (message "impatient-mode 已关闭"))
    ;; 未开 → 开启 + 打开浏览器
    (impatient-mode 1)
    (let ((url (format "http://localhost:%d/imp/live/%s"
                       (bound-and-true-p httpd-port)
                       (url-hexify-string (buffer-name)))))
      (browse-url url)
      (message "impatient-mode 已开启 → %s" url))))
;; C-c C-b: 外部浏览器实时预览 (impatient + 自动刷新)
(global-set-key (kbd "C-c C-b") #'my-impatient-preview)

;; ---------- xwidget-webkit 内嵌预览 (Emacs 窗口内, 跑 CSS/JS) ----------
;; 需要 Emacs 编译时 --with-xwidgets (nix-darwin 已配).
;; xwidget-webkit 只在 GUI Emacs 下可用 (display-graphic-p).
;; 把当前 buffer HTML 写临时文件, 在下方分屏用 xwidget-webkit 渲染.
(defvar my-xwidget-preview-tmpfile
  (make-temp-file "emacs-xw-preview" nil ".html")
  "xwidget 预览临时文件 (每次刷新覆写).")

(defun my-xwidget-preview ()
  "在下方分屏用 xwidget-webkit 渲染当前 HTML buffer.
内嵌真 WebKit 引擎, CSS/JS 全跑 (跟浏览器一样).
每次按 C-c C-p 刷新.  仅 GUI Emacs 可用."
  (interactive)
  (if (not (display-graphic-p))
      (message "xwidget 需要 GUI Emacs (终端模式不支持)")
    (let ((content (buffer-substring-no-properties (point-min) (point-max))))
      (with-temp-buffer
        (insert content)
        (write-region (point-min) (point-max) my-xwidget-preview-tmpfile nil 'silent)))
    (let ((url (concat "file://" my-xwidget-preview-tmpfile)))
      ;; xwidget-webkit-browse-url 自建 buffer *xwidget-webkit: <url>*,
      ;; 不能预先 get-buffer-create (会是普通 buffer 没 xwidget).
      ;; 调用它后会切换到 xwidget buffer, 再 display-buffer 分屏显示.
      (xwidget-webkit-browse-url url)
      ;; 找到刚创建的 xwidget buffer (名含 "xwidget-webkit")
      (let ((xw-buf (seq-find (lambda (b)
                                (string-match-p "xwidget-webkit" (buffer-name b)))
                              (buffer-list))))
        (when xw-buf
          (display-buffer xw-buf
                          '((display-buffer-below-selected display-buffer-reuse-window)
                            (window-height . 20)))))
      (message "xwidget-webkit 预览已刷新 (C-c C-p 再按刷新)"))))

;; C-c C-p: C-c <letter> 用户保留键, 全局绑定安全 (主预览键)
(global-set-key (kbd "C-c C-p") #'my-xwidget-preview)

;; ---------- JS/TS 缩进: 2 空格 (默认 4) ----------
;; js-ts-mode 和 js-mode 都读 js-indent-level; js-ts-mode 额外读
;; js-ts-mode-indent-offset (treesit 用), 两个都设 2。
(setq-default js-indent-level 2
              js-ts-mode-indent-offset 2)

(add-hook 'js-ts-mode-hook (lambda () (setq-local tab-width 2)))

;; ---------- 运行当前 JS 文件 (node) ----------
(defun my-js-run ()
  "运行当前 JS 文件 (node), 结果输出到 *js-run* buffer 并自动弹出显示."
  (interactive)
  (if (not (derived-mode-p 'js-ts-mode 'js-mode))
      (message "当前 buffer 不是 JS 文件")
    (let ((file (buffer-file-name)))
      (if (not file)
          (message "文件还没保存过, 先 C-x C-s 保存")
        (save-buffer)
        (shell-command (format "node \"%s\"" file) "*js-run*")
        ;; 在下方弹出结果窗口 (高 12 行), 不抢光标焦点
        (display-buffer "*js-run*"
                        '((display-buffer-below-selected
                           display-buffer-reuse-window)
                          (window-height . 12)))
        (message "已运行: node %s (结果在下方 *js-run*)" file)))))

(with-eval-after-load 'js
  ;; js-ts-mode-map 要等 js.el 加载后才存在, 直接 define-key 会 void 报错
  ;; (init-dev.el 加载时 js 未加载, 2026-08 实测启动报错)
  (define-key js-ts-mode-map (kbd "C-c C-x") #'my-js-run))

;; ---------- Rust 一键运行 (nvim <leader>r 的 Emacs 版, 2026-09-18) ----------
;; 规则与 nvim lua/config/run.lua 对齐:
;;   ① 项目模式: 向上找到 Cargo.toml → 在项目根 cargo run
;;      - 单 bin → 裸 cargo run; 当前文件是某 bin 源码 → --bin 点名;
;;      - 多 bin 且当前文件不是任何 bin → 列出候选, 不瞎猜 (nvim 同款)
;;   ② 单文件模式: 没有 Cargo.toml → rustc 编译到 /tmp 再运行
;;   ③ 工具链纪律: rustc/cargo 只在项目 devShell (Nix 铁律),
;;      向上找到 .envrc 才加 "direnv exec . " 前缀, 否则裸跑 (报错更直白)
;;   ④ 输出走 compile buffer: 错误行可点击, M-g n/p 跳转, 复跑自动替换旧内容
(require 'cl-lib)

(defun my-rust--direnv-prefix (dir)
  "DIR 向上有 .envrc 返回 \"<direnv绝对路径> exec . \", 否则空串."
  (if (locate-dominating-file dir ".envrc")
      (concat (or (executable-find "direnv")
                  "/run/current-system/sw/bin/direnv")
              " exec . ")
    ""))

(defun my-rust--package-name (root)
  "读 ROOT/Cargo.toml 的 [package] 段第一处 name (不引 TOML 解析器, nvim 同款)."
  (let ((in-pkg nil) (name nil))
    (when (file-exists-p (expand-file-name "Cargo.toml" root))
      (with-temp-buffer
        (insert-file-contents (expand-file-name "Cargo.toml" root))
        (while (and (not name) (not (eobp)))
          (let ((line (buffer-substring-no-properties
                       (line-beginning-position) (line-end-position))))
            (when (string-match-p "^[ \t]*\\[.*\\]" line)
              (setq in-pkg (string-match-p "^[ \t]*\\[package\\]" line)))
            (when (and in-pkg (null name)
                       (string-match "^[ \t]*name[ \t]*=[ \t]*\"\\(.*\\)\"" line))
              (setq name (match-string 1 line))))
          (forward-line 1))))
    name))

(defun my-rust--cargo-bins (root path)
  "返回 (BINS . BIN-OF): 项目 ROOT 的可运行 bin 列表 + 当前 PATH 对应的 bin 名 (或 nil).
bin 名规则与 nvim run.lua cargo_bins 一致:
  src/main.rs → Cargo.toml [package] name;  src/bin/x.rs → x;  src/bin/x/main.rs → x."
  (let ((seen '()) (bins '()))
    (cl-flet ((add (n)
               (when (and n (> (length n) 0) (not (member n seen)))
                 (setq seen (cons n seen))
                 (setq bins (append bins (list n))))))
      (let* ((main-rs (expand-file-name "src/main.rs" root))
             (pkg-name (my-rust--package-name root)))
        (when (file-exists-p main-rs)
          (add (or pkg-name
                   (file-name-nondirectory (directory-file-name root)))))
        (let ((bin-dir (expand-file-name "src/bin" root)))
          (when (file-directory-p bin-dir)
            (dolist (f (directory-files bin-dir t "\\.rs\\'"))
              (add (file-name-base f)))
            (dolist (d (directory-files bin-dir t "^[^.]" t))
              (when (file-directory-p d)
                (let ((m (expand-file-name "main.rs" d)))
                  (when (file-exists-p m)
                    (add (file-name-nondirectory d))))))))
        (let ((bin-of nil))
          (cond ((file-equal-p path main-rs)
                 (setq bin-of (or pkg-name
                                  (file-name-nondirectory (directory-file-name root)))))
                ((file-in-directory-p path (expand-file-name "src/bin" root))
                 (let* ((rel (file-relative-name path (expand-file-name "src/bin" root)))
                        (parts (split-string rel "/")))
                   (if (and (= (length parts) 2)
                            (string= (nth 1 parts) "main.rs"))
                       (setq bin-of (nth 0 parts))
                     (setq bin-of (file-name-base path))))))
          (cons bins bin-of))))))

(defun my-rust--resolve-command (path)
  "PATH (.rs 绝对路径) → (命令 . 运行目录) cons; 多 bin 无法确定时 message 候选并返回 nil.
与 nvim run.lua M.resolve 对齐: Cargo.toml 项目 → cargo run, 否则 rustc 单文件.
⚠️ locate-dominating-file 返回缩写路径 (~/...), 必须 expand-file-name 还原绝对路径,
否则 shell-quote-argument 会把 ~ 转义成 \\~ → cd 失败 (2026-09-18 实测)."
  (setq path (expand-file-name path))
  (let* ((dir (file-name-directory path))
         (root (when-let ((r (locate-dominating-file dir "Cargo.toml")))
                 (expand-file-name r))))
    (if root
        (let* ((r (my-rust--cargo-bins root path))
               (bins (car r))
               (bin-of (cdr r))
               (args (cond ((<= (length bins) 1) "run")
                           (bin-of (concat "run --bin "
                                           (shell-quote-argument bin-of))))))
          (if args
              (cons (format "cd %s && %scargo %s"
                            (shell-quote-argument root)
                            (my-rust--direnv-prefix root)
                            args)
                    root)
            (message "这个 crate 有多个可运行目标 (%s), 打开对应源文件再运行"
                     (mapconcat #'identity bins ", "))
            nil))
      (let ((out (concat "/tmp/emacs-rust-run-" (file-name-base path))))
        (cons (format "cd %s && %srustc %s -o %s && %s"
                      (shell-quote-argument dir)
                      (my-rust--direnv-prefix dir)
                      (shell-quote-argument (file-name-nondirectory path))
                      (shell-quote-argument out)
                      (shell-quote-argument out))
              dir)))))

(defun my-rust-run ()
  "运行当前 Rust 文件/项目 (nvim <leader>r 的 Emacs 版).
Cargo 项目 → 项目根 cargo run (多 bin 自动点名 --bin); 无 Cargo.toml → rustc 编译到 /tmp 后运行.
工具链走项目 devShell: 向上有 .envrc 自动加 direnv exec 前缀.
输出进 *compilation* buffer: 错误行可点击, M-g n/p 跳转, 复跑自动替换旧内容."
  (interactive)
  (if (not (derived-mode-p 'rust-ts-mode 'rust-mode))
      (message "当前 buffer 不是 Rust 文件")
    (let ((path (buffer-file-name)))
      (if (not path)
          (message "文件还没保存过, 先 C-x C-s 保存")
        (save-buffer)
        (let ((res (my-rust--resolve-command path)))
          (when res
            (compile (car res))))))))

(with-eval-after-load 'rust-ts-mode
  ;; rust-ts-mode-map 要等 rust-ts-mode.el 加载后才存在 (与 js 同款坑)
  (define-key rust-ts-mode-map (kbd "C-c C-r") #'my-rust-run))

;; ---------- JS/TS 变量引用高亮补丁 ----------
;; js-ts-mode 默认只给赋值左值/声明上变量色, return a + b 这类表达式里
;; 的变量引用无 face (白色)。补一条规则: 所有 identifier 染上 variable-use-face,
;; :override 默认 nil → 不覆盖已有 face (函数名/关键字/字符串不受影响)。
;; 需要 treesit-font-lock-level 4 (init-env.el 已设)。
(defvar my-js-ts-var-use-extra
  (when (treesit-available-p)
    (treesit-font-lock-rules
     :feature 'variable-use
     :language 'javascript
     '((identifier) @font-lock-variable-use-face)))
  "补 js-ts-mode 变量引用高亮的规则 (只补空白, 不覆盖已有 face).")

(defun my-js-ts-patch-var-use ()
  "把变量引用规则追加到 js-ts-mode 的 font-lock settings 并重新高亮."
  (when (and (derived-mode-p 'js-ts-mode)
             my-js-ts-var-use-extra
             (not (memq (car my-js-ts-var-use-extra) treesit-font-lock-settings)))
    ;; treesit-font-lock-rules 返回规则列表 (每个规则是 (query enable override feature)),
    ;; append 时直接展开, 不能多包一层 (2026-08 实测: 包一层会整列表被当 query 报错)
    (setq-local treesit-font-lock-settings
                (append treesit-font-lock-settings my-js-ts-var-use-extra))
    (font-lock-flush)))

(add-hook 'js-ts-mode-hook #'my-js-ts-patch-var-use)

(provide 'init-dev)
;;; init-dev.el ends here
