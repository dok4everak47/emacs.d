;;; init-qol.el --- 生活质感补丁 (目录整洁 / 持久化 / 格式化 / 会话 / 拼写 / 阅读) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; 参考 https://github.com/mauromotion/dotfiles/blob/main/common/emacs/config.org
;; 挑出的互补片段, 只取本配置此前缺的能力, 不搬对方的 evil / treemacs /
;; mu4e / denote 骨架 (与本仓库 meow / dashboard / ~/org 架构冲突)。
;;
;; no-littering     : backup / auto-save / lockfile 集中到 ~/.cache/emacs
;; undo-fu-session  : 撤销历史跨重启持久化 (配合 meow 的 u / vundo, 不动键位)
;; apheleia         : 保存时自动格式化 (nix 除外, 该语言已由 eglot 负责)
;; vterm-toggle     : 弹出式终端, C-c T 从底部拉起 / 收起
;; ace-window + avy : C-c g 选窗口 / 跳字符; 原生 C-x 前缀绑定 (s- / M-o 旁路)
;; elfeed           : 终端里的 RSS 阅读器 (按 C 收藏到 ~/org/feeds.org)
;; save-place / auto-revert / repeat-mode : 光标位置持久化 / 外部改动自动重载 / 命令连按
;; jinx             : 实时拼写检查 (enchant 引擎, 只查英文)
;; 杂项             : delete-by-moving-to-trash / pixel-scroll / recentf 调优 / ace 窗口

;;; Code:

;; ---------- no-littering: 临时文件不落到项目目录 ----------
;; Emacs 默认把 `file~` 备份、`#file#` 自动保存写在原文件旁边, 污染 git 工作区。
;; no-littering 统一重定向到 ~/.cache/emacs, 并把大部分运行时文件也挪过去。
;; ⚠️ 刻意不设 (setq user-emacs-directory "~/.cache/emacs") — 那会把整个
;; .emacs.d 搬家, 本仓库结构 (lisp/ / README / git) 会失效。
(defvar no-littering-etc-directory)
(defvar no-littering-var-directory)
(use-package no-littering
  :ensure t
  :demand t
  :init
  (setq no-littering-etc-directory "~/.cache/emacs/etc/"
        no-littering-var-directory "~/.cache/emacs/var/")
  :config
  (setq backup-directory-alist
        `(("." . ,(no-littering-expand-var-file-name "backup/"))))
  (setq auto-save-file-name-transforms
        `((".*" ,(no-littering-expand-var-file-name "auto-save/") t)))
  (setq create-lockfiles t)        ; 保留锁文件, 防两个 Emacs 同时改同一文件
  (no-littering-theme-backups))

;; ⚠️ no-littering 在上面把自己的 rmh-elfeed-org-files 指向了
;; ~/.cache/emacs/etc/elfeed/rmh-elfeed.org; 这里立刻改回本仓库的 elfeed.org,
;; 必须放在 no-littering 加载之后 (顶层 setq, 不能放 elfeed-org 的 :custom —
;; 那会在 no-littering 之前执行而被覆盖)。
(defvar rmh-elfeed-org-files)
(setq rmh-elfeed-org-files
      (list (expand-file-name "elfeed.org" user-emacs-directory)))

;; ---------- undo-fu-session: 撤销历史跨重启 ----------
;; 关掉 Emacs 再开, undo 栈能接着用 (原生只有本次会话)。
;; 只用 session 持久化, 不引入 undo-fu 的键位 — meow 的 u (meow-undo) 与
;; C-x u (vundo) 保持不变, 两者共享同一份 buffer-undo-list。
(defvar undo-fu-session-directory)
(use-package undo-fu-session
  :ensure t
  :init
  (setq undo-fu-session-directory
        (expand-file-name "undo-fu-session/" no-littering-var-directory))
  :config
  (undo-fu-session-global-mode 1))

;; ---------- apheleia: 保存时自动格式化 ----------
;; 为每种语言挑最优外部格式化器 (prettier / gofmt / rustfmt / black / nixfmt ...)。
;; ⚠️ nix-mode 例外: init-nix.el 已用 eglot → nixd → nixfmt 在 before-save-hook
;; 格式化 — 两条链同时跑会互相打架, 这里把 nix-mode 从 apheleia 列表摘掉。
;; ⚠️ 其余 LSP 语言 (php/python/js/ts/rust) 的 lsp-format-buffer-on-save 也在跑,
;; 外部格式化器与 LSP 结果一致且幂等, 保持开启; 若发现重复动作可同样摘除。
(use-package apheleia
  :ensure t
  :config
  (apheleia-global-mode 1)
  (setq apheleia-mode-alist (assq-delete-all 'nix-mode apheleia-mode-alist)))

;; ---------- vterm-toggle: 弹出式终端 ----------
;; C-c T 从底部拉起/收起 30% 高的终端, 退出终端自动关 buffer。
;; 与 init-term.el 的 C-c v (新窗口复用) / C-c V (新窗口新建) 并存:
;; C-c T 是"同一个终端反复在底部弹出"的轻量用法。
(use-package vterm-toggle
  :ensure t
  :bind (("C-c T" . vterm-toggle))
  :config
  (setq vterm-toggle-fullscreen-p nil)
  (add-to-list 'display-buffer-alist
               '((lambda (buffer-or-name _action)
                   (with-current-buffer (get-buffer buffer-or-name)
                     (eq major-mode 'vterm-mode)))
                 (display-buffer-reuse-window display-buffer-at-bottom)
                 (window-height . 0.3))))

;; ---------- ace-window: 多窗口一键选 ----------
;; ⚠️ M-o 已被 embark-act 占用, 这里不用对方配置里的 M-o。
;; 挂在原生 C-x 前缀下 (C-x o 是默认换窗口), s- 方向键 (init-tools.el) 也不动。
(use-package ace-window
  :ensure t
  :bind (("C-x o" . ace-window)))

;; ---------- avy: 字符跳转 ----------
;; 屏幕上每个词首字母打高亮标签, 敲 1-2 个字母跳过去, 比连续 C-f / 鼠标快。
;; ⚠️ 不设 C-: 前缀 (与 meow 状态机可能冲突), 用 M- 前缀的默认键。
(use-package avy
  :ensure t
  :bind (("M-g c" . avy-goto-char-2)
         ("M-g w" . avy-goto-word-1)
         ("M-g l" . avy-goto-line)))

;; ---------- elfeed + elfeed-org: RSS 阅读 ----------
;; C-c j 打开搜索页 (只列 6 个月内未读); 订阅清单放在本仓库的 elfeed.org
;; (已 gitignore, 各机不同; 与 ~/org 笔记分开, 不混进 Agenda)。
;; 订阅写法: 一个 org 标题=一个标签, 标题下每行一个 feed URL, 如
;;   * 科技
;;   https://example.com/feed.xml
;; elfeed-org 在每次打开 elfeed 前把 elfeed.org 解析进 elfeed-feeds。
(use-package elfeed
  :ensure t
  :bind (("C-c j" . elfeed))
  :custom
  (elfeed-db-directory (no-littering-expand-var-file-name "elfeed/db/"))
  (elfeed-search-filter "@6-months-ago +unread"))

(defvar rmh-elfeed-org-files)
(use-package elfeed-org
  :ensure t
  :after elfeed
  :config
  (elfeed-org))

;; elfeed-link: 让 elfeed 条目能被 org-store-link / org-capture 识别,
;; 这样从阅读页就能把"当前这条"抓进 ~/org (取到 :title / :external-link 等元数据)。
(use-package elfeed-link
  :after elfeed
  :demand t)   ; elfeed-link.el 随 elfeed 包提供, 非独立包: 不能 :ensure (会去找不存在的 "elfeed-link")

;; ---------- elfeed 收藏到 org: C 键 ----------
;; 搜索页/阅读页按 C → org-capture 模板 "R" → 追加进 ~/org/feeds.org 的"收藏"标题。
;; 关键点: 先 org-store-link 再调 capture, 并让 elfeed-link 的 :store 函数优先命中
;; (org-store-link 会优先调用非 core 的 :store 函数), 于是 %:title/%:external-link/
;; %:feed-title/%:authors 才有值。C 在两个模式里都空闲 (阅读页的 R 保留给"可读模式")。
(defun my-elfeed-capture-entry ()
  "把当前 Elfeed 条目收藏到 ~/org/feeds.org。"
  (interactive)
  (cond
   ((derived-mode-p 'elfeed-show-mode)
    (org-store-link nil)
    (org-capture nil "R"))
   ((derived-mode-p 'elfeed-search-mode)
    (let ((entries (ignore-errors (elfeed-search-selected :ignore-region))))
      (cond
       ((= 1 (length entries))
        (elfeed-show-entry (car entries))
        (org-store-link nil)
        (org-capture nil "R"))
       ((> (length entries) 1)
        (user-error "这个命令一次只收藏一条; 请把光标停在单条上再按 C"))
       (t (user-error "当前没有选中条目")))))
   (t (call-interactively #'org-capture))))

(with-eval-after-load 'elfeed
  (define-key elfeed-search-mode-map (kbd "C") #'my-elfeed-capture-entry)
  (define-key elfeed-show-mode-map (kbd "C") #'my-elfeed-capture-entry))

;; ---------- 会话状态 / 文件一致性 ----------
;; save-place: 重开文件回到上次光标位置 (Emacs 默认关闭, 实测本机为 nil)
(when (fboundp 'save-place-mode)
  (save-place-mode 1))
(defvar auto-revert-interval)
;; global-auto-revert: 外部改动的文件自动重载 — magit 切分支、mbsync 同步
;; Maildir 后, Emacs 里的旧内容自动更新, 不用手动 revert-buffer。
;; dired 另有 dired-auto-revert-buffer (init-tools.el), 不受本项影响。
(when (fboundp 'global-auto-revert-mode)
  (global-auto-revert-mode 1))
(setq auto-revert-interval 5)              ; 轮询间隔 5s (默认亦为 5, 写死防变)
;; repeat-mode: 同类命令连按省掉前缀 — 内置 repeat-map 已覆盖 M-g n/p
;; (逐个错误) / C-x Left-Right (切 buffer) / C-x ^ { } (连续调窗口大小) 等。
;; (本机 C-x o 改 ace-window、C-x u 改 vundo 均无 repeat-map, 属例外)
(when (fboundp 'repeat-mode)
  (repeat-mode 1))

;; ---------- jinx: 实时拼写检查 (只查英文, 中文自动跳过) ----------
;; 载体是 enchant-2 引擎 (nix profile install nixpkgs#enchant, 见 README 安装节)。
;; jinx 异步检查: 编辑时后台跑 enchant, 只给疑似错词加波浪下划线, 不卡输入;
;; AppleSpell 词典无中文 → 中文不判错, 中英混排写作几乎无噪音。
;; 用法: 有下划线的词 M-x jinx-correct; M-x jinx-mode 手动开关。
;; ⚠️ 只挂文本类 buffer (text/org/markdown), 不进 prog-mode — 代码里变量名/
;;    缩写会被整片标红, 那是噪音不是错。
(defvar jinx-languages)
(defvar jinx-mode)
(defvar jinx--compile-flags)
(use-package jinx
  :ensure t
  :hook ((text-mode org-mode markdown-mode) . jinx-mode)
  :custom
  (jinx-languages "en_US")                 ; 引擎实际可用 en_US/en_GB 等 AppleSpell 词典
  :config
  ;; jinx 首次启用时现场编译 C 模块 (jinx-mod.c)。默认靠 pkg-config 定位
  ;; enchant, 失败则退回 /usr/include/enchant-2 等硬编码路径。本机 enchant
  ;; 在 nix (~/.nix-profile, nix profile install nixpkgs#enchant), 且未装
  ;; pkg-config → 两条路都落空。显式补 nix 的 include/lib, 编译器直接命中
  ;; (pkg-config 兜底路径 /usr/... 是空的, 留着无副作用, 见 README 安装节)。
  (setq jinx--compile-flags
        (append jinx--compile-flags
                (list (concat "-I" (expand-file-name "~/.nix-profile/include/enchant-2"))
                      (concat "-L" (expand-file-name "~/.nix-profile/lib"))))))

;; ---------- 杂项: 删除进废纸篓 / 像素滚动 / recentf 调优 ----------
(defvar recentf-max-saved-items)
(defvar recentf-auto-cleanup)
(when (fboundp 'delete-selection-mode)
  (delete-selection-mode 1))               ; 选中即替换 (输入覆盖选区)
(setq delete-by-moving-to-trash t)         ; delete-file 走 macOS 废纸篓可恢复
(setq recentf-max-saved-items 200          ; 最近文件记 200 条 (默认 20)
      recentf-auto-cleanup 'never)         ; 不自动清理失效条目 (外置盘拔了也在)
(when (fboundp 'pixel-scroll-precision-mode)
  (pixel-scroll-precision-mode 1))         ; 触控板逐像素滚动, 不整行跳

(provide 'init-qol)
;;; init-qol.el ends here
