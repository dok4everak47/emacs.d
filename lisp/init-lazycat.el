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
  (vundo-window-min-height 12))

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
  (markdown-live-preview-delete-export 'delete-on-destroy))

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
