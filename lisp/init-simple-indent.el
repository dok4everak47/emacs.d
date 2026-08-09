;;; init-simple-indent.el --- 编程语言统一简单缩进 -*- lexical-binding: t -*-

;;; Commentary:
;;
;; 对所有 prog-mode 系语言 (js/nix/racket/python/... 所有编程文件) 统一:
;;   - TAB: 每按一次多缩 2 空格 (固定缩进, 不做 S-expr/语法对齐)
;;   - RET: 光标在行尾 → 新行缩进 = 上一行缩进 (同级继续)
;;          光标不在行尾 → 新行缩进 = 旧行缩进 + 2 (换行后进入下一层)
;;
;; 挂载 = 复制到 ~/.emacs.d/lisp/ + init.el 加载链加
;;   (require 'init-simple-indent nil t)

;;; Code:

(defun my-simple-indent-tab ()
  "TAB: 固定缩进, 每按一次多 2 空格."
  (interactive)
  (if (looking-at "^[ \t]*$")
      (indent-to tab-width)
    (insert (make-string tab-width ?\s))))

(defun my-simple-indent-newline ()
  "RET: 行尾 → 同级缩进; 非行尾 → 再缩进一层."
  (interactive)
  (let ((col (current-indentation))
        (at-eol (eolp)))
    (newline)
    (if at-eol
        (indent-to col)
      (indent-to (+ col tab-width)))))

;; 统一挂到所有编程语言 (prog-mode 是所有编程 mode 的父类)
(add-hook 'prog-mode-hook
          (lambda ()
            (setq-local indent-line-function #'my-simple-indent-tab)
            (setq-local tab-width 2)
            (setq-local electric-indent-inhibit t)   ; 关掉 RET 自动缩进 (我们自己管)
            ;; ⚠️ 三个都要绑: 有的键盘 Return 发 <return> 而非 RET,
            ;; 只绑 RET 会导致 Return 走 electric-indent 默认 newline
            (local-set-key (kbd "RET") #'my-simple-indent-newline)
            (local-set-key (kbd "<return>") #'my-simple-indent-newline)
            (local-set-key (kbd "C-m") #'my-simple-indent-newline)))

(provide 'init-simple-indent)
;;; init-simple-indent.el ends here