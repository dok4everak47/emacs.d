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

(provide 'init-tools)
;;; init-tools.el ends here
