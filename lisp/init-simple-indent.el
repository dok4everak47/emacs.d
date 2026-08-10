;;; init-simple-indent.el --- 编程语言统一简单缩进 -*- lexical-binding: t -*-

;;; Commentary:
;;
;; 对所有 prog-mode 系语言 (js/nix/racket/python/... 所有编程文件) 统一:
;;   - TAB: 每按一次多缩 2 空格 (固定缩进, 不做 S-expr/语法对齐)
;;   - RET: 换行并继承当前行缩进 (同级, 不递增; 2026-08 从"非行尾+2"改为纯继承)
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
  "RET: 换行并继承当前行缩进 (同级, 不递增).
2026-08 修改: 原实现\"非行尾回车缩进+2 (进入下一层)\", 用户反馈
连续回车缩进逐次增加 → 改为统一继承当前行缩进, 回车不再改缩进。"
  (interactive)
  (let ((col (current-indentation)))
    (newline)
    (indent-to col)))

(defun my-simple-indent-backspace ()
  "Backspace: 按缩进单位删 (一次删 tab-width 个空格), 否则删 1 字符."
  (interactive)
  (let ((col (current-column)))
    (if (and (> col 0)
             (= 0 (% col tab-width))          ; 光标列正好是 tab-width 的整数倍
             (save-excursion                 ; 且光标前是 tab-width 个空格 (在缩进区)
               (let ((bol (line-beginning-position)))
                 (and (> (point) bol)
                      (string-match-p
                       (concat "^ *$")
                       (buffer-substring bol (point)))))))
        (delete-backward-char tab-width)
      (delete-backward-char 1))))

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
            (local-set-key (kbd "C-m") #'my-simple-indent-newline)
            ;; Backspace 按缩进单位删 (2 空格一块), 不逐个删
            (local-set-key (kbd "DEL") #'my-simple-indent-backspace)
            (local-set-key (kbd "<backspace>") #'my-simple-indent-backspace)
            (local-set-key (kbd "<delete>") #'my-simple-indent-backspace)
            (local-set-key (kbd "C-h") #'my-simple-indent-backspace)))

;; meow insert 态 C-h 退格 → 按缩进单位删, 已直接在 init-meow.el 的
;; meow-insert-state-keymap 定义处覆盖 (比 with-eval-after-load 可靠, 加载顺序无关)。

(provide 'init-simple-indent)
;;; init-simple-indent.el ends here