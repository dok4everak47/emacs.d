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

;; ---------- flymake: 实时语法检查 ----------
;; Emacs 29+ 内置, 不需要额外安装包
;; 配合 eglot (已在 ide.el 中配置) 使用时, LSP 诊断自动走 flymake
(use-package flymake
  :ensure nil                                 ; 内置包, 不从 ELPA 安装
  :bind
  (:map flymake-mode-map
        ("M-g n" . flymake-goto-next-error)   ; 下一个错误
        ("M-g p" . flymake-goto-prev-error)   ; 上一个错误
        ("C-c ! l" . flymake-show-buffer-diagnostics)) ; 错误列表
  :custom
  (flymake-fringe-indicator-position 'left-fringe) ; 左侧 fringe 显示标记
  (flymake-margin-enabled t)                  ; margin 也显示标记
  (flymake-margin-indicator-position 'left-margin)
  :config
  ;; 编程语言 major-mode 启动时自动开 flymake
  ;; (eglot 启动时会自动启用 flymake, 这里兜底非 LSP 场景)
  (add-hook 'prog-mode-hook #'flymake-mode))

;; ---------- flymake 错误列表美化 ----------
;; flymake-show-buffer-diagnostics 弹出的列表默认样式简陋,
;; 用 consult 集成后可以模糊搜索 + 预览跳转
(with-eval-after-load 'consult
  ;; 如果安装了 consult, 用 consult-flymake 替代默认跳转
  (when (fboundp 'consult-flymake)
    (define-key flymake-mode-map (kbd "C-c ! f") #'consult-flymake)))

;; ---------- impatient-mode: HTML/CSS 实时预览 ----------
;; 编辑 HTML/CSS 时在浏览器实时刷新 (类似 VSCode Live Server)
;; 用法: 打开 HTML 文件 → M-x impatient-mode → 浏览器访问 localhost:8080
;; 保存即刷新, 不需要手动 reload
(use-package impatient-mode
  :ensure t
  :commands (impatient-mode)
  :custom
  (impatient-default-delay 0.5)              ; 0.5s 防抖
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

(provide 'init-dev)
;;; init-dev.el ends here
