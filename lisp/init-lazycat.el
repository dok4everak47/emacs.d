;;; init-lazycat.el --- 借鉴 manateelazycat 的高频小插件 -*- lexical-binding: t -*-

;;; Commentary:
;; 来源: https://manateelazycat.github.io/2022/11/07/how-i-use-emacs/
;; 只选纯 Elisp 轻量插件 (无 EAF/PyQt 重依赖)。
;; 清华 ELPA 镜像有的包直接装; 镜像没有的用等价包或自写小函数:
;;   super-save     : 停手 1 秒自动保存 (替代 auto-save, 功能相同)
;;   vundo          : 可视化撤销树, 可回退任意撤销分支
;;   symbol-overlay : 光标处 symbol 高亮, n/p 跳转, r 一键重命名
;;   popper         : 临时弹窗管理 (Help/编译/xref 等一键收起)
;;   olivetti       : 写作内容居中 (写博客/文档)
;;   pangu-spacing  : 中英文之间自动加空格 (替代 wraplish)
;;   move-text      : 整行上下移动
;;   open-newline   : 自写, 不动光标在行上/下方开新行
;;   duplicate-line : 自写, 复制当前行
;;
;; 键位 (已核对 init.el / init-org.el / ide.el / init-term.el 无冲突):
;;   C-x u    vundo (替代默认 undo, 功能完全覆盖)
;;   C-c s s  高亮当前 symbol      C-c s n/p 下一个/上一个
;;   C-c s r  重命名               C-c s d 清除全部高亮
;;   C-c p p  收起/弹出临时窗口    C-c p t 切换弹窗类型
;;   C-c o o  写作居中开关
;;   C-c e n  行下方开新行         C-c e u 行上方开新行
;;   C-c d d  复制当前行
;;   move-text 不绑键 (org 占用 M-<up>/M-<down>), 用 M-x move-text-up/down
;;   所有功能也可在菜单栏 "快捷工具" 鼠标点选

;;; Code:

;; ---------- super-save: 停手即存 (替代 auto-save) ----------
(use-package super-save
  :ensure t
  :config
  (setq super-save-idle-duration 1)   ; 停手 1 秒自动保存
  (super-save-mode 1))

;; ---------- vundo: 可视化撤销树 ----------
(use-package vundo
  :ensure t
  :bind (("C-x u" . vundo))
  :custom
  (vundo-glyph-alist vundo-unicode-symbols) ; 用清晰的 Unicode 箭头而非 emoji
  (vundo-compact-display t)
  (vundo-window-max-height 12)) ; 窗口最大高度 (原 vundo-window-min-height 拼错, 包无此变量, 从未生效)

;; ---------- symbol-overlay: 单文件重构 ----------
(use-package symbol-overlay
  :ensure t
  :hook (prog-mode . symbol-overlay-mode)
  :bind (("C-c s s" . symbol-overlay-put)
         ("C-c s n" . symbol-overlay-jump-next)
         ("C-c s p" . symbol-overlay-jump-prev)
         ("C-c s r" . symbol-overlay-rename)
         ("C-c s d" . symbol-overlay-remove-all)))

;; ---------- popper: 临时弹窗管理 ----------
(use-package popper
  :ensure t
  :bind (("C-c p p" . popper-toggle)
         ("C-c p t" . popper-toggle-type)
         ("C-c p o" . popper-cycle))
  :init
  (setq popper-reference-buffers
        '("\\*Messages\\*" "\\*Warnings\\*" "\\*Backtrace\\*"
          "\\*xref\\*" "\\*compilation\\*" "\\*Async Shell Command\\*"
          "\\*Help\\*" "\\*grep\\*" "\\*Occur\\*" "\\*shell\\*"
          help-mode compilation-mode grep-mode occur-mode))
  :config
  (popper-mode 1))

;; ---------- olivetti: 写作居中 ----------
(use-package olivetti
  :ensure t
  :bind (("C-c o o" . olivetti-mode))
  :custom
  (olivetti-body-width 100)
  (olivetti-minimum-body-width 60))

;; ---------- pangu-spacing: 中英文自动加空格 (替代 wraplish) ----------
(use-package pangu-spacing
  :ensure t
  :custom
  (pangu-spacing-real-insert-separtor t) ; 真的插入空格 (而非仅显示)
  :config
  (global-pangu-spacing-mode 1))

;; ---------- markdown-mode: Markdown 编辑 + Emacs 内预览 ----------
;; 打开 .md 自动进 gfm-mode (GitHub 风格语法高亮)
;; 预览: C-c C-c l (markdown-live-preview-mode)
;;   → 用内置 eww 在 Emacs 内部渲染, 无需外部浏览器, 编辑实时刷新
;;   → 转换走 md2html.py (纯 Python 标准库, 无 markdown 命令依赖)
;;   → 退出预览: 关掉预览窗口即可
(use-package markdown-mode
  :ensure t
  :mode (("\\.md\\'" . gfm-mode)
         ("\\.markdown\\'" . gfm-mode)
         ("\\.mdown\\'" . gfm-mode))
  :custom
  (markdown-command (list "python3" (expand-file-name "md2html.py" user-emacs-directory)))
  (markdown-live-preview-window-function #'markdown-live-preview-window-eww)
  (markdown-live-preview-delete-export 'delete-on-destroy)
  ;; 预览窗口位置: 'right = 预览在右侧 (左右并排, VS Code 风格);
  ;; 想改回上下堆叠(预览在下方)就把 'right 改成 'below
  (markdown-split-window-direction 'right)
  :config
  ;; 显式关闭预览: C-c C-c q (meow 的 q 是 meow-quit, 不能用来关预览)
  ;; markdown-live-preview-mode 是 buffer-local 变量, 只在源码 buffer 为 t;
  ;; 在预览窗口 (*eww*) 里是 nil → 必须通过 markdown-live-preview-source-buffer
  ;; 找到源码 buffer 再关闭, 否则在预览窗口按 q 会"没反应"。
  (defun my-markdown-preview-close ()
    "关闭 Markdown 实时预览 (无论光标在源码窗口还是预览窗口).
关闭后删除预览窗口, 回到单窗口, 不会残留源文件副本."
    (interactive)
    (let* ((preview-win (and (boundp 'markdown-live-preview-buffer)
                             (buffer-live-p markdown-live-preview-buffer)
                             (get-buffer-window markdown-live-preview-buffer t)))
           (src
            (cond
             ((and (boundp 'markdown-live-preview-mode) markdown-live-preview-mode)
              (current-buffer))
             ((and (boundp 'markdown-live-preview-source-buffer)
                   (buffer-live-p markdown-live-preview-source-buffer))
              markdown-live-preview-source-buffer))))
      (when src
        (with-current-buffer src
          (when (and (boundp 'markdown-live-preview-mode) markdown-live-preview-mode)
            (markdown-live-preview-mode -1))))
      ;; kill-buffer 后预览窗口还在但 fallback 显示其他 buffer (源文件副本),
      ;; 删除该窗口, 回到干净布局
      (when (window-live-p preview-win)
        (delete-window preview-win))))
  ;; VS Code 式预览追踪: 光标在源码移动/编辑时, 预览窗口自动滚到对应章节
  ;; 定位: 先找光标所在章节标题的纯文本在预览 buffer 里的位置;
  ;; 找不到 (标题带行内符号等) 就按源码/预览字符比例粗略跟随。
  (defun my-md-preview-current-heading ()
    "返回光标所在章节的标题纯文本 (去掉 markdown 符号), 不在任何标题下返回 nil.
光标停在标题行本身时取当前行 (而非上一个标题); 否则向上找最近的标题."
    (save-excursion
      (let (txt)
        ;; 先看当前行是不是标题
        (save-excursion
          (beginning-of-line)
          (when (looking-at "^[ \t]*#\\{1,6\\}[ \t]+\\(.*\\)$")
            (setq txt (match-string-no-properties 1))))
        ;; 不是就向上找最近的标题
        (unless txt
          (save-excursion
            (goto-char (line-beginning-position))
            (when (re-search-backward "^[ \t]*#\\{1,6\\}[ \t]+\\(.*\\)$" nil t)
              (setq txt (match-string-no-properties 1)))))
        (when txt
          ;; 行内 markdown: [a](url) → a, 去掉 * ` _
          (setq txt (replace-regexp-in-string "\\[[^]]*\\]([^)]*)" "\\1" txt))
          (setq txt (replace-regexp-in-string "[*_`]" "" txt))
          (setq txt (replace-regexp-in-string "[ \t]+" " " txt))
          (string-trim txt)))))

  (defun my-markdown-preview-follow ()
    "让预览窗口跟随源码光标所在章节滚动 (VS Code 效果)."
    (when (and (buffer-live-p markdown-live-preview-buffer)
               (eq (current-buffer) (window-buffer (selected-window))))
      (let ((preview-win (get-buffer-window markdown-live-preview-buffer t)))
        (when (window-live-p preview-win)
          (let ((heading (my-md-preview-current-heading))
                (src-len (max 1 (- (point-max) (point-min))))
                (src-pos (- (point) (point-min))))
            (with-selected-window preview-win
              (goto-char (point-min))
              (let ((target (and heading
                                 ;; 精确匹配: 行首到行尾整行等于 heading
                                 ;; (避免 "FastAPI" 里的 API 子串误匹配)
                                 (re-search-forward
                                  (format "^%s$"
                                          (regexp-quote heading))
                                  nil t))))
                (if target
                    (goto-char target)
                  ;; 兜底: 按字符比例粗略定位
                  (let ((pv-len (max 1 (- (point-max) (point-min)))))
                    (goto-char (point-min))
                    (forward-char (round (* (/ src-pos src-len) pv-len)))))
                (recenter 1))))))))

  ;; 反向跟随: 光标在预览窗口滚动时, 源码窗口滚到对应章节 (VS Code 双向同步)
  (defun my-md-preview-current-heading-from-preview ()
    "从预览 buffer 当前窗口顶部位置反推对应章节标题, 返回标题纯文本.
策略: 窗口顶部在预览 buffer 的字符比例 → 源码 buffer 同比例位置 → 向上找最近章节标题."
    (let* ((top (window-start (selected-window)))
           (pv-len (max 1 (- (point-max) (point-min))))
           (ratio (/ (float top) pv-len))
           (src markdown-live-preview-source-buffer))
      (when (and src (buffer-live-p src))
        (with-current-buffer src
          (let* ((src-len (- (point-max) (point-min)))
                 (src-pos (round (* ratio src-len))))
            (save-excursion
              (goto-char (min src-pos (point-max)))
              ;; 向上找最近的 markdown 标题行
              (when (re-search-backward "^[ \t]*#\\{1,6\\}[ \t]+\\(.*\\)$" nil t)
                (let ((txt (match-string-no-properties 1)))
                  (setq txt (replace-regexp-in-string "\\[[^]]*\\]([^)]*)" "\\1" txt))
                  (setq txt (replace-regexp-in-string "[*_`]" "" txt))
                  (setq txt (replace-regexp-in-string "[ \t]+" " " txt))
                  (string-trim txt)))))))))

  (defun my-markdown-preview-reverse-follow ()
    "光标在预览窗口时, 让源码窗口滚到对应章节 (VS Code 双向同步)."
    (when (and (boundp 'markdown-live-preview-source-buffer)
               (buffer-live-p markdown-live-preview-source-buffer)
               (eq (current-buffer) (window-buffer (selected-window))))
      (let ((src markdown-live-preview-source-buffer)
            (heading (my-md-preview-current-heading-from-preview)))
        (when (and src heading)
          (let ((src-win (get-buffer-window src t)))
            (when (window-live-p src-win)
              (with-selected-window src-win
                (goto-char (point-min))
                (when (re-search-forward
                       (concat "^[ \t]*#\\{1,6\\}[ \t]+"
                               (regexp-quote heading)
                               "[ \t]*$")
                       nil t)
                  (recenter 1)))))))))

  ;; 触控板/滚轮 → 移动光标 (配合预览跟随; 只在预览开着时生效, 关掉预览恢复普通滚动)
  ;; 实测: macOS 触控板双指下滑(看下文)触发 wheel-down → next-line (2026-08 对调过)
  (defvar my-md-preview-wheel-map
    (let ((map (make-sparse-keymap)))
      (define-key map [wheel-up] #'previous-line)
      (define-key map [wheel-down] #'next-line)
      (define-key map [vertical-wheel-up] #'previous-line)
      (define-key map [vertical-wheel-down] #'next-line)
      map)
    "预览跟随辅助: 触控板滚动时移动光标的键位.")

  (define-minor-mode my-md-preview-wheel-mode
    "预览跟随辅助: 触控板滚动改为移动光标 (方向与普通滚动一致, 光标动 → 预览跟随)."
    :lighter " 🖱F"
    :keymap my-md-preview-wheel-map)

  (add-hook 'markdown-live-preview-mode-hook
            (lambda ()
              (if markdown-live-preview-mode
                  (progn
                    (add-hook 'post-command-hook #'my-markdown-preview-follow nil t)
                    (my-md-preview-wheel-mode 1))
                (remove-hook 'post-command-hook #'my-markdown-preview-follow t)
                (my-md-preview-wheel-mode -1))))
  (define-key markdown-mode-command-map (kbd "q") #'my-markdown-preview-close)
  ;; 预览 buffer (*eww*) 也绑定 q / C-c C-c q → 关闭 (只影响 live-preview 的
  ;; eww buffer, 用 buffer-local keymap, 不影响普通网页浏览)
  (defvar-local my-md-preview-font-scale 1.0
    "当前预览 buffer 的字体缩放倍率 (1.0 = 默认).")
  (defvar-local my-md-preview-font-remaps nil
    "当前预览 buffer 的 face-remap 句柄列表 (清理用).")

  (defun my-md-preview-font-zoom (delta)
    "预览 buffer 字体缩放, DELTA 为倍率增量 (如 0.1 放大, -0.1 缩小)."
    (let ((scale (max 0.5 (min 2.5 (+ (or my-md-preview-font-scale 1.0) delta)))))
      (setq my-md-preview-font-scale scale)
      (dolist (h my-md-preview-font-remaps)
        (face-remap-remove-relative h))
      (setq my-md-preview-font-remaps
            (mapcar
             (lambda (f)
               (let ((h (face-attribute f :height nil 'default)))
                 (face-remap-add-relative
                  f
                  `(:height ,(if (floatp h) (* h scale) scale)))))
             '(default shr-h1 shr-h2 shr-h3 shr-h4 shr-h5 shr-h6
                      shr-code shr-text shr-link)))
      (message "预览字体: %.2fx" scale)))

  (defun my-md-preview-font-zoom-in ()
    "预览字体放大 10%."
    (interactive)
    (my-md-preview-font-zoom 0.1))

  (defun my-md-preview-font-zoom-out ()
    "预览字体缩小 10%."
    (interactive)
    (my-md-preview-font-zoom -0.1))

  (defun my-markdown-preview-eww-keys (&rest _args)
    "给 live-preview 的 eww buffer 加 buffer-local 绑定: 关闭键 + 滚动动光标.
从源码 buffer 或 eww buffer 调用均可 (eww 每次渲染后都会重置 keymap,
所以同时挂在 eww-after-render-hook 上, 渲染完成自动重挂)."
    (let ((pv (cond
               ((and (boundp 'markdown-live-preview-buffer)
                     (buffer-live-p markdown-live-preview-buffer))
                markdown-live-preview-buffer)
               ((and (boundp 'markdown-live-preview-source-buffer)
                     (buffer-local-value 'markdown-live-preview-source-buffer
                                         (current-buffer)))
                (current-buffer)))))
      (when (and pv (buffer-live-p pv))
        (with-current-buffer pv
          ;; 预览文本自动换行 (显示层软换行, 单词边界断行; 不改变 buffer 内容)
          (visual-line-mode 1)
          (setq-local word-wrap t)
          (setq-local truncate-lines nil)
          ;; 反向跟随: 光标在预览窗口动时, 源码滚到对应章节
          (add-hook 'post-command-hook #'my-markdown-preview-reverse-follow nil t)
          (let ((map (make-sparse-keymap)))
            (set-keymap-parent map (current-local-map))
            (define-key map (kbd "q") #'my-markdown-preview-close)
            (define-key map (kbd "C-c C-c q") #'my-markdown-preview-close)
            ;; 预览字体缩放 (只影响预览窗口)
            (define-key map (kbd "C-c C-c +") #'my-md-preview-font-zoom-in)
            (define-key map (kbd "C-c C-c -") #'my-md-preview-font-zoom-out)
            ;; 预览窗口里触控板滚动也移动光标 (与源码 wheel-map 同向)
            ;; macOS 触控板发 vertical-wheel-* 事件, 普通滚轮发 wheel-* 事件, 都绑上
            (define-key map [wheel-up] #'previous-line)
            (define-key map [wheel-down] #'next-line)
            (define-key map [vertical-wheel-up] #'previous-line)
            (define-key map [vertical-wheel-down] #'next-line)
            (use-local-map map))))))
  (advice-add 'markdown-live-preview-mode :after #'my-markdown-preview-eww-keys)
  (add-hook 'eww-after-render-hook #'my-markdown-preview-eww-keys))

;; ---------- move-text: 整行上下移动 ----------
(use-package move-text
  :ensure t)   ; 命令 move-text-up / move-text-down, 不绑键 (避开 org 的 M-<up>)

;; ---------- open-newline: 不动光标在行上/下方开新行 (自写) ----------
(defun my-open-line-below ()
  "在当前行下方开新行, 光标保持不动 (跳到新行)."
  (interactive)
  (save-excursion
    (end-of-line)
    (newline-and-indent)))

(defun my-open-line-above ()
  "在当前行上方开新行, 光标保持不动 (跳到新行)."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (newline-and-indent)
    (previous-line)))

;; ---------- duplicate-line: 复制当前行 (自写) ----------
(defun my-duplicate-line ()
  "复制当前行到下一行, 光标保持在原行."
  (interactive)
  (let ((col (current-column)))
    (save-excursion
      (let ((line (thing-at-point 'line t)))
        (end-of-line)
        (newline)
        (insert line)))
    (move-to-column col)))

;; ---------- 键位 ----------
(global-set-key (kbd "C-c e n") #'my-open-line-below)
(global-set-key (kbd "C-c e u") #'my-open-line-above)
(global-set-key (kbd "C-c d d") #'my-duplicate-line)

;; ---------- GUI 菜单: "快捷工具" (鼠标点选, 不记快捷键) ----------
(easy-menu-define nil global-map "快捷工具"
  '("快捷工具"
    ["撤销树 (vundo)" vundo t]
    ["高亮当前符号" symbol-overlay-put t]
    ["符号重命名" symbol-overlay-rename t]
    ["收起/弹出临时窗口" popper-toggle t]
    ["写作居中 (olivetti)" olivetti-mode t]
    ["行下方开新行" my-open-line-below t]
    ["行上方开新行" my-open-line-above t]
    ["复制当前行" my-duplicate-line t]
    ["上移当前行" move-text-up t]
    ["下移当前行" move-text-down t]))

(provide 'init-lazycat)
;;; init-lazycat.el ends here
