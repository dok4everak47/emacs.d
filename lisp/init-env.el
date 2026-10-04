;;; init-env.el --- 环境集成 (代理 / PATH / direnv / snippets / treesit) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; exec-path-from-shell: 从 shell 继承 PATH (nix/homebrew 的命令在 GUI Emacs 里才能找到)
;; url-proxy-services: 给内置 url.el 系 (org-gcal / elfeed / eww / 包管理) 挂代理
;; envrc: direnv 集成 (进入 .envrc 项目目录自动设置环境变量)
;; yasnippet: 代码片段模板展开
;; treesit-auto: 自动安装 tree-sitter 语法, 代码高亮/缩进更精准

;;; Code:

;; ---------- url-proxy-services: 内置 url.el 走代理 ----------
;; shell 已导出 http_proxy/https_proxy=127.0.0.1:7890 (本机 ClashBar 混合口),
;; 但 Emacs 的 urllib 不读这些环境变量 — url-proxy-services 默认 nil, 于是
;; org-gcal (googleapis.com) / elfeed (国外 RSS) / eww / package-refresh
;; 全部直连, 被墙就干等超时。
;;
;; 设 no_proxy 排除清单: 本地回环 + 本机已直连的国内域名 (飞书 / 火山方舟 /
;; moonshot) — 与 shell 的 $no_proxy 保持一致。条目可用正则 (如 "\\.feishu\\.cn")。
;; ⚠️ 只加 "http"/"https": smtpmail 走 socket 隧道 (见 init.el) 不经这里;
;;    TRAMP 的 ssh 亦不走 url.el — 加代理不影响它们。
(defvar url-proxy-services)
(setq url-proxy-services
      '(("http"  . "127.0.0.1:7890")
        ("https" . "127.0.0.1:7890")
        ("no_proxy" . "localhost\\|127\\.0\\.0\\.1\\|::1\\|feishu\\.cn\\|larksuite\\.com\\|volces\\.com\\|moonshot\\.cn")))

;; ---------- exec-path-from-shell: 继承 shell PATH ----------
;; GUI Emacs 不继承 shell 的 PATH (nix/homebrew 的命令找不到)
;; 用此包把 shell PATH 同步到 exec-path 和 PATH 环境变量
;;
;; 性能优化: exec-path-from-shell-initialize 每次启动都跑一个 login shell
;; 抓 PATH (实测 0.89s)。首次抓取后把结果缓存到 cache/exec-path.el,
;; 之后启动直接读缓存 (~0.01s)。nix 环境变了想刷新: M-x my-refresh-exec-path。
(use-package exec-path-from-shell
  :ensure t
  :when (memq window-system '(mac ns pgtk))
  :custom
  (exec-path-from-shell-arguments '("-l"))   ; login shell
  :config
  (defvar my-exec-path-cache-file
    (expand-file-name "cache/exec-path.el" user-emacs-directory))

  (defun my-refresh-exec-path ()
    "重新从 shell 抓取 PATH 并更新缓存 (nix 环境变了时用)."
    (interactive)
    (exec-path-from-shell-initialize)
    (make-directory (file-name-directory my-exec-path-cache-file) t)
    (with-temp-file my-exec-path-cache-file
      (insert (format "(setq exec-path '%S)\n(setenv \"PATH\" %S)\n"
                      exec-path (getenv "PATH"))))
    (message "exec-path refreshed"))

  (if (file-exists-p my-exec-path-cache-file)
      (load my-exec-path-cache-file)         ; 缓存命中: 直接读, 不跑 shell
    (my-refresh-exec-path)))

;; ---------- envrc: direnv 集成 ----------
;; 项目根目录有 .envrc 文件时, 自动 direnv allow 并加载环境变量
;; ⚠️ envrc-show-summary-in-minibuffer 默认 t: 每次加载把整套环境变量 diff
;; (几十行 +AR +CC +NIX_*...) 打印到 minibuffer/messages 刷屏 → 关掉。
(use-package envrc
  :ensure t
  :init
  (envrc-global-mode 1)
  :custom
  (envrc-show-summary-in-minibuffer nil))

;; ---------- yasnippet: 代码片段 ----------
;; 输入关键词 + Tab 展开 (如 "main" → main 函数模板)
(use-package yasnippet
  :ensure t
  :init
  (yas-global-mode 1)
  :hook (prog-mode . yas-minor-mode)      ; 强制编程 buffer 启用 (LSP snippet 展开依赖)
  :custom
  (yas-triggers-in-field nil)              ; TAB 在占位符内固定跳下一个字段 (嵌套 snippet 改从补全弹窗选)
  (yas-use-menu nil)                       ; 隐藏菜单栏 YASnippet 菜单 (只留快捷键)
  :config
  ;; yasnippet-snippets: 社区通用 snippet 库
  (use-package yasnippet-snippets
    :ensure t
    :after yasnippet
    :demand t))

;; ---------- treesit-auto: tree-sitter 自动安装 ----------
;; Emacs 29+ 内置 tree-sitter, 但语法包需手动装
;; treesit-auto 按文件类型自动安装对应语法, 高亮/缩进更精准
;;
;; 性能优化: global-treesit-auto-mode 启动激活会扫描全部已装语法 (0.45s),
;; 延迟到首次打开文件时再激活, 启动时间省 0.45s。
(use-package treesit-auto
  :ensure t
  :custom
  (treesit-auto-install 'prompt)           ; 首次使用时提示安装
  ;; php 排除: php-ts-mode 在 Emacs 30.2 要求 6 个 grammar (php/phpdoc/html/
  ;; js/jsdoc/css), 缺 phpdoc/jsdoc 拒绝启动; php 改用 php-mode (纯 font-lock)。
  ;; 排除后 treesit-auto 的 remap/auto-mode-alist 都不会碰 .php。
  (treesit-auto-langs
   (seq-remove (lambda (l) (memq l '(php nix))) ; nix 改用 nix-mode (SMIE 缩进, 比 treesit 稳)
               (mapcar #'treesit-auto-recipe-lang treesit-auto-recipe-list)))
  :config
  (require 'treesit)  ; 确保 tree-sitter 核心已加载 (batch 下需显式)
  ;; 高亮级别 4: 启用 function-call / variable-use 等细化 face,
  ;; 函数调用、函数定义、变量、字符串各自独立颜色 (2026-08 加)
  (setq treesit-font-lock-level 4)
  (defvar my-treesit-auto-activated nil)
  (defun my-treesit-auto-activate ()
    "首次打开文件时激活 treesit-auto (懒加载, 加速启动)."
    (unless my-treesit-auto-activated
      (setq my-treesit-auto-activated t)
      ;; 用 'all: 无条件注册所有 ts-mode 到 auto-mode-alist (php 已排除)
      (global-treesit-auto-mode 1)
      (treesit-auto-add-to-auto-mode-alist 'all)
      ;; 坑: 当前文件打开时 treesit-auto 还没激活, 已按旧 alist 落到
      ;; 非 ts-mode (如 js-mode)。激活后按新 auto-mode-alist 重新判定当前
      ;; 文件该用什么 mode, 不同就切过去。
      (let ((new-mode (and buffer-file-name
                           (assoc-default buffer-file-name auto-mode-alist
                                          #'string-match-p))))
        (when (and new-mode
                   (not (eq new-mode major-mode))
                   (fboundp new-mode))
          (funcall new-mode)))))
  ;; ⚠️ 用 find-file-hook (Emacs 30 after-find-file 结尾 run 的就是它;
  ;; 没有 after-find-file-hook 这个 hook, 挂它会永不触发 — 2026-08 实测)
  (add-hook 'find-file-hook #'my-treesit-auto-activate)
  ;; 启动时立即激活: 避免"首次打开文件才激活"导致文件先落旧 mode 再切换
  ;; (二次初始化 + 卡顿, 2026-08 用户报 treemacs 打开文件卡顿)。代价: 启动 +~0.5s。
  (my-treesit-auto-activate))

;; ---------- 性能修复: treesit-auto 别每次判模式都重建 remap 表 ----------
;; 2026-10-04 实测定位 (用户报「保存 org 笔记卡好一会」的根因):
;; global-treesit-auto-mode 会给 set-auto-mode-0 挂 :before advice
;; (treesit-auto--set-major-remap), 而它每次判文件模式都调
;; treesit-auto--build-major-mode-remap-alist 重建整张 remap 表 — 逐个 recipe
;; 跑 treesit-ready-p (语法包可用性检查)。本机 60 个 recipe ≈ 1.5s/次,
;; 且一次 set-auto-mode 会调它好几次。
;; 后果: 打开任何文件 ~1.5s; 保存 ~/org 笔记时索引自动重建 (内部 write-file
;; 写 index.org 也走 set-auto-mode) → 每次保存卡 ~3s。
;; 修法: remap 表一个会话内只取决于「本机装了哪些语法包」, 建一次缓存即可。
;; 只缓存 treesit 生成的那部分, 用户自己的 major-mode-remap-alist 仍实时生效。
;; 实测: 保存笔记 2.94s → 0.32s, 打开 .org 文件 1.51s → 0.001s (remap 结果不变)。
(defvar my-treesit-remap-cache nil
  "treesit-auto 生成的 remap 条目 (缓存); nil = 需重建。")
(defun my-treesit-remap-refresh ()
  "重建 treesit-auto 的 remap 缓存 (新装语法包后调一次)."
  (interactive)
  ;; 在临时 buffer 里 build: 那里 major-mode-remap-alist 就是全局值,
  ;; 便于把 build 结果切成「用户原有部分 + treesit 部分」。
  (let* ((base (length (default-value 'major-mode-remap-alist)))
         (full (with-temp-buffer (treesit-auto--build-major-mode-remap-alist))))
    (setq my-treesit-remap-cache (seq-drop full base))
    (message "treesit-auto remap 缓存已重建 (%d 条)" (length my-treesit-remap-cache))))
(defun my-treesit-set-major-remap (&rest _)
  "替代 treesit-auto--set-major-remap: 用缓存, 不再每次重建。"
  (unless my-treesit-remap-cache (my-treesit-remap-refresh))
  (setq-local major-mode-remap-alist
              (append major-mode-remap-alist my-treesit-remap-cache)))
(advice-add 'treesit-auto--set-major-remap :override #'my-treesit-set-major-remap)
;; treesit-auto 装完新语法包后缓存要失效 (否则新 ts-mode 当次不生效);
;; 用 :around 看返回值 — 只有真装成功 (非 nil) 才清缓存, 用户答「不装」不清。
(defun my-treesit-remap-after-install (orig lang &rest args)
  "装语法包成功后清 remap 缓存 (见 `my-treesit-remap-cache`)."
  (let ((installed (apply orig lang args)))
    (when installed (setq my-treesit-remap-cache nil))
    installed))
(advice-add 'treesit-auto--prompt-to-install-package :around
            #'my-treesit-remap-after-install)

(provide 'init-env)
;;; init-env.el ends here
