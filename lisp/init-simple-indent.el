;;; init-simple-indent.el --- 编程语言统一简单缩进 -*- lexical-binding: t -*-

;;; Commentary:
;;
;; 对所有 prog-mode 系语言 (js/nix/racket/python/... 所有编程文件) 统一:
;;   - TAB: 每按一次多缩 2 空格 (固定缩进, 不做 S-expr/语法对齐)
;;   - RET: 首次回车新行继承当前行缩进 (rkt=2/py=4 当前层级);
;;          当前行是空行时再回车 → 不缩进回行首 (第二次回车取消缩进)
;;
;; 挂载 = 复制到 ~/.emacs.d/lisp/ + init.el 加载链加
;;   (require 'init-simple-indent nil t)

;;; Code:

(defun my-simple-indent-tab ()
  "TAB: 固定缩进, 每按一次多 tab-width 空格 (当前缩进 +2)."
  (interactive)
  (if (looking-at "^[ \t]*$")
      (indent-line-to (+ (current-indentation) tab-width))
    (insert (make-string tab-width ?\s))))

(defun my-simple-indent-newline ()
  "RET: 首次回车新行继承当前行缩进 (rkt=2/py=4 当前层级);
连续第二次回车 (紧接上次回车, 且当前行是空行) → 不缩进回行首.
已有缩进的空行上回车仍继承缩进 (只\"连续第二次\"才取消).
光标后的行尾空白留在旧行, 不推到新行 (避免缩进叠加)."
  (interactive)
  (let ((empty-line (save-excursion
                      (beginning-of-line)
                      (looking-at-p "^[ \t]*$")))
        (col (current-indentation)))
    ;; 非空行时, 光标后的前导空白留在旧行, 不带到新行 (避免缩进叠加:
    ;; 光标后是空格(或空格+内容)时, newline 会把它们推到新行行首,
    ;; indent-to 再加缩进 → 缩进叠加变大)
    (unless empty-line
      (when (looking-at "[ \t]*")
        (delete-region (point) (match-end 0))))
    (newline)
    (indent-to (if (and empty-line
                        (eq last-command 'my-simple-indent-newline))
                   0
                 col))))

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

(defun my-lisp-newline-and-indent ()
  "Lisp 系 RET:
  - 普通回车 (行中/行尾): 新行缩进 = 当前行缩进 + tab-width (继续缩进一层,
      rkt 就 +2); 连续第二次回车 (紧接上次回车, 空行) → 不缩进回行首
  - 括号对间回车 (光标在 electric-pair 自动补的右括号前):
      新行缩进 = 当前行缩进 + tab-width (进入下一层),
      右括号推到下一行并缩进到匹配开括号的列 (括号对应缩进):
  (define (f)
    (define (g)|)  →  (define (f)
                          (define (g)
                            █
                          )    ← 缩进 2, 对齐 (define (g)
                      )        ← 缩进 0, 对齐 (define (f)"
  (interactive)
  (let ((close-paren (and (not (eobp))
                          (eq (char-after) ?\))))   ; 光标后紧跟右括号
        (empty-line (save-excursion
                      (beginning-of-line)
                      (looking-at-p "^[ \t]*$")))
        (col (current-indentation)))
    ;; 非空行时, 光标后的前导空白留在旧行, 不带到新行 (避免缩进叠加)
    (unless empty-line
      (when (looking-at "[ \t]*")
        (delete-region (point) (match-end 0))))
    (newline)
    ;; 连续第二次回车 (上次也是回车, 且当前行是空行) → 回行首;
    ;; 否则 → 当前行缩进 + tab-width (继续缩进一层)
    (indent-to (if (and empty-line
                        (eq last-command 'my-lisp-newline-and-indent))
                   0
                 (+ col tab-width)))
    (when close-paren
      (save-excursion
        (newline 1 t)                    ; 右括号推到下一行
        ;; 右括号缩进 = 匹配开括号的列 (syntax-ppss 的 START)
        (let* ((open-pos (nth 1 (syntax-ppss))))
          (when open-pos
            (let ((open-col (save-excursion
                              (goto-char open-pos)
                              (current-column))))
              (beginning-of-line)
              (delete-horizontal-space)
              (indent-to open-col))))))))

;; 统一挂到所有编程语言 (prog-mode 是所有编程 mode 的父类)
;; ⚠️ Lisp 系 (racket/scheme/lisp/emacs-lisp) 特殊处理:
;;    它们有自己的括号深度智能缩进 (racket-indent-line / lisp-indent-line),
;;    固定 2 空格缩进会毁掉嵌套括号的对齐 → 用 my-lisp-newline-and-indent
;;    (换行 + 括号深度缩进 + 括号对间右括号跳下一行), TAB/缩进函数保留原生.
(add-hook 'prog-mode-hook
          (lambda ()
            (if (derived-mode-p 'lisp-mode 'emacs-lisp-mode 'racket-mode 'scheme-mode)
                (progn
                  ;; Lisp 系: Enter 换行 + 括号深度智能缩进 + 括号对间开新行
                  (setq-local indent-tabs-mode nil)   ; 用空格缩进 (elisp 默认会用 tab)
                  (setq-local tab-width 2)
                  ;; TAB/缩进函数用固定缩进 (每按一次 +2, 可任意次数),
                  ;; 不用 racket-indent-line 语法缩进 (按一次就固定, 无法继续缩)
                  (setq-local indent-line-function #'my-simple-indent-tab)
                  (local-set-key (kbd "TAB") #'my-simple-indent-tab)
                  (local-set-key (kbd "RET") #'my-lisp-newline-and-indent)
                  (local-set-key (kbd "<return>") #'my-lisp-newline-and-indent)
                  (local-set-key (kbd "C-m") #'my-lisp-newline-and-indent)
                  ;; Backspace 按缩进单位删 (2 空格一块), 不逐个删
                  (local-set-key (kbd "DEL") #'my-simple-indent-backspace)
                  (local-set-key (kbd "<backspace>") #'my-simple-indent-backspace)
                  (local-set-key (kbd "<delete>") #'my-simple-indent-backspace)
                  (local-set-key (kbd "C-h") #'my-simple-indent-backspace))
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
              (local-set-key (kbd "C-h") #'my-simple-indent-backspace))))

;; meow insert 态 C-h 退格 → 按缩进单位删, 已直接在 init-meow.el 的
;; meow-insert-state-keymap 定义处覆盖 (比 with-eval-after-load 可靠, 加载顺序无关)。

(provide 'init-simple-indent)
;;; init-simple-indent.el ends here