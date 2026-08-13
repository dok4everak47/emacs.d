;;; init-paren.el --- 括号可视化: 深度配色 + 匹配高亮 -*- lexical-binding: t -*-

;;; Commentary:
;;
;; Racket/Lisp 嵌套括号深时难以分辨层次, 三层互补方案:
;;   - rainbow-delimiters (MELPA): 每个嵌套深度一种颜色 (DrRacket 同款配色),
;;     挂在 Lisp 系 major-mode (racket/scheme/lisp/emacs-lisp)。
;;     默认深色色板是低饱和灰/蓝/绿 (grey55/#b0b1a3/...) 相邻层难分,
;;     这里重定义 9 层 face 为 doom-one 高区分度色板。
;;   - show-paren (内置): 非 Lisp 语言 (js/nix/python/...) 的匹配对高亮。
;;     Lisp 系 (racket/scheme/lisp/emacs-lisp) 禁用 show-paren: 其 overlay
;;     priority=1000 会压过 hl-paren 的白色加粗, 空括号 () 上两 overlay 完全
;;     重叠渲染竞争导致闪烁; hl-paren 的 highlight-parentheses-highlight-adjacent
;;     已承担 Lisp 系的匹配对高亮。
;;   - highlight-parentheses (MELPA): 从光标向外把包围它的若干层括号各涂
;;     一色 + 最内层加粗, 一眼看出"当前在第几层"。
;;
;; 三者互补: rainbow 管"整体层次一眼可辨", show-paren 管"当前这一对在哪",
;; highlight-parentheses 管"我正处在哪一层"。

;;; Code:

(use-package paren
  :ensure nil                                  ; 内置包, 不从 ELPA 安装
  :custom
  (show-paren-style 'parenthesis)               ; 只高亮匹配的两个括号
  (show-paren-delay 0)                         ; 立即显示, 不等默认 0.125s 防抖
  (show-paren-when-point-inside-paren t)       ; 点在括号内部时也高亮匹配对
  (show-paren-when-point-in-periphery t)       ; 点在括号首/尾字符时也高亮
  (show-paren-context-when-offscreen nil)      ; 关闭离屏 context (child-frame/overlay 都随 command 闪现)
  ;; Lisp 系禁用 show-paren: hl-paren 的 highlight-parentheses-highlight-adjacent
  ;; 已承担匹配对高亮, 且 show-paren overlay priority=1000 会压过 hl-paren 白色
  ;; (空括号 () 上两个 overlay 完全重叠, 渲染竞争导致闪烁, 2026-08 实测)
  (show-paren-predicate
   '(and (not (derived-mode . lisp-mode))
         (not (derived-mode . emacs-lisp-mode))
         (not (derived-mode . scheme-mode))
         (not (derived-mode . racket-mode))))
  :config
  (show-paren-mode 1))

;; doom-one 高区分度色板: 9 层互不撞色, 相邻层直接可辨
;; (取自项目已有的 doom-one 色系, 与 init-nix.el 的 nix-mode 配色一致)
(defconst my-paren-colors
  ["#ff6c6b" ; 1 红
   "#ECBE7B" ; 2 黄
   "#98be65" ; 3 绿
   "#46D9FF" ; 4 青
   "#51afef" ; 5 蓝
   "#c678dd" ; 6 紫
   "#da8548" ; 7 橙
   "#a9a1e1" ; 8 紫罗兰
   "#d19a66"] ; 9 棕
  "括号分层配色 (doom-one 色系, 高区分度).")

(use-package rainbow-delimiters
  :ensure t
  :commands (rainbow-delimiters-mode)
  :hook ((racket-mode . rainbow-delimiters-mode)
         (scheme-mode . rainbow-delimiters-mode)
         (lisp-mode . rainbow-delimiters-mode)
         (emacs-lisp-mode . rainbow-delimiters-mode))
  :config
  ;; 用 doom-one 色板覆盖默认 depth face (默认深色色板相邻层几乎同色)
  (dotimes (i 9)
    (face-spec-set (intern (format "rainbow-delimiters-depth-%d-face" (1+ i)))
                   `((((class color) (background dark))
                      (:foreground ,(aref my-paren-colors i)))
                     (t (:foreground ,(aref my-paren-colors i)))))))

(use-package highlight-parentheses
  :ensure t
  :commands (highlight-parentheses-mode)
  :hook ((racket-mode . highlight-parentheses-mode)
         (scheme-mode . highlight-parentheses-mode)
         (lisp-mode . highlight-parentheses-mode)
         (emacs-lisp-mode . highlight-parentheses-mode))
  :custom
  ;; 最内层 (index 0, 光标所在层) 用白色+加粗, 与 rainbow 9 色板完全区分;
  ;; 往外各层复用 my-paren-colors 色板
  (highlight-parentheses-colors (cons "#ffffff" (seq-map #'identity my-paren-colors)))
  (highlight-parentheses-attributes '((:weight bold))) ; 最内层(当前层)加粗
  (highlight-parentheses-highlight-adjacent t) ; 同时高亮相邻括号 (同 show-paren)
  (highlight-parentheses-delay 0.05))          ; 响应快一点

(provide 'init-paren)
;;; init-paren.el ends here
