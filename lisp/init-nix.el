;;; init-nix.el --- Nix 语言支持: 高亮 + 补全 + LSP + 保存格式化 -*- lexical-binding: t -*-

;;; Commentary:
;;
;; 放弃 nix-ts-mode (treesit 缩进对空行/let-in 不稳), 改用 nix-mode (SMIE 缩进,
;; 纯 elisp 不依赖 grammar)。nixd LSP 与 major mode 解耦, 补全/格式化不受影响。
;;
;; 四件套:
;;   - nix-mode (MELPA): 语法高亮 + SMIE 缩进 (2 空格, 经典括号深度算法)
;;   - nixd (nixpkgs, nix profile install): Nix LSP server, eglot 提供
;;     补全/悬停/跳转; 补全弹窗走 corfu (init-completion.el)
;;   - nixfmt (nixpkgs): 保存时格式化 (C-x C-s → eglot-format-buffer → nixd → nixfmt)
;;   - tree-sitter-nix grammar: 已按 treesit-auto-langs 排除 nix (见 init-env.el)

;;; Code:

(use-package nix-mode
  :ensure t
  :mode ("\\.nix\\'" . nix-mode)
  :hook ((nix-mode . eglot-ensure)
         (nix-mode . (lambda () (setq-local smie-indent-basic 2)))) ; 2 空格缩进 (buffer-local, 不影响其他 SMIE mode)
  :custom
  (nix-mode-use-smie t)                       ; SMIE 缩进 (默认即 t, 显式锁死)
  :config
  ;; ---------- 显式分配 nix face 颜色 (doom-one 色板) ----------
  ;; 问题: nix-mode 的 face 全部 :inherit font-lock-*-face, 而 doom-one 里
  ;; functions/builtin/variables 语义色全是同一紫 (magenta #c678dd) → nix
  ;; 代码变量/函数/builtin 看着同色。这里显式拉开:
  ;;   keyword→蓝   builtin→紫   constant→黄   attribute(变量)→橙
  ;;   function(自定义)→青   antiquote→紫罗兰   string 保持绿 (撞色点见下)
  ;; ⚠️ 变量别用绿: font-lock-string-face 在 doom-one 也是绿 #98be65, 会撞色
  ;;    ("上一版"全绿就是这个原因)。
  (dolist (spec '((nix-keyword-face        . "#51afef")  ; 蓝  keywords
                  (nix-builtin-face        . "#c678dd")  ; 紫  builtin
                  (nix-constant-face       . "#ECBE7B")  ; 黄  constants
                  (nix-attribute-face      . "#da8548")  ; 橙  变量/属性名 (避开绿)
                  (nix-antiquote-face      . "#a9a1e1")  ; 紫罗兰  ${...}
                  (nix-store-path-face     . "#4db5bd"))) ; teal store path
    (set-face-foreground (car spec) (cdr spec)))
  (set-face-foreground 'nix-store-path-realised-face   "#4db5bd")
  (set-face-foreground 'nix-store-path-unrealised-face "#5B6268")

  ;; ---------- 函数调用高亮 (nix-mode 自带规则不含函数名) ----------
  ;; 渲染实测: `pkgs.stdenv.mkDerivation`、`pkgs.lib.version` 这类点号名
  ;; 全落 nil (无 face, 默认前景色)。自定义 face + font-lock 规则补齐,
  ;; 但只染"正在调用"的点号名 (后跟 [{ (] 才算), 属性读取保持默认色:
  ;;   pkgs.stdenv.mkDerivation {   ← 调用 → 青
  ;;   version = pkgs.lib.version;   ← 读取 → 默认色
(defface nix-function-face
    '((t (:foreground "#46D9FF")))           ; 青: 与 keyword(蓝)/builtin(紫)均区分
    "nix: 函数调用 (自定义, nix-mode 未提供)")
  (defvar nix-function-face 'nix-function-face)
  (font-lock-add-keywords
   'nix-mode
   `((,(concat "\\([a-zA-Z_][a-zA-Z0-9_'-]*"
               "\\(?:\\.[a-zA-Z_][a-zA-Z0-9_'-]*\\)+\\)"
               "[ \t\r\n]*[{(]")             ; 仅当调用时 ({ 块 / ( 分组, 跨行亦可
      1 'nix-function-face t)))
  ;; 函数头参数名: {config, pkgs, inputs, ...} → 变量橙
  ;; 每条规则从 { 锚定到第 N 个参数 (不消费前缀, 无遗漏);
  ;; 支持 4 个参数 (更多罕见, 末尾不染)。实测 { inherit ... } 里的
  ;; inherit 已被 nix-mode 关键字规则染蓝, 不会被误染橙。
  ;; ⚠️ 空白用 [ \t\r\n]* 而非 \s-*: nix 常用跨行函数头
  ;;    ({\n  config, pkgs, ... \n}:), 而 \s- 只匹配字符表中
  ;;    whitspace 类的字符, 默认表里 \n 是 comment-end (类 '>'),
  ;;    会导致整个跨行函数头匹配失败。
  (let ((ws "[ \t\r\n]*")
        (name "[a-zA-Z_][a-zA-Z0-9_'-]*"))
    (font-lock-add-keywords
     'nix-mode
     `((,(concat "{" ws "\\(" name "\\)") 1 'nix-attribute-face t)
       (,(concat "{" ws name ws "," ws "\\(" name "\\)") 1 'nix-attribute-face t)
       (,(concat "{" ws name ws "," ws name ws "," ws "\\(" name "\\)") 1 'nix-attribute-face t)
       (,(concat "{" ws name ws "," ws name ws "," ws name ws "," ws "\\(" name "\\)") 1 'nix-attribute-face t))))
  ;; 保存时格式化 (走 eglot → nixd → nixfmt)
  ;; ⚠️ eglot-format-buffer 在 LSP 未连时抛 jsonrpc-error → 阻断保存!
  ;; 守卫: 只在 eglot--managed-mode 已激活时才格式化, 否则跳过 (正常保存)。
  (defun my-nix-format-on-save ()
    "保存时格式化 nix buffer, 仅当 eglot 已连上 nixd。"
    (when (bound-and-true-p eglot--managed-mode)
      (condition-case nil
          (eglot-format-buffer)
        (error nil))))
  (add-hook 'nix-mode-hook
            (lambda () (add-hook 'before-save-hook #'my-nix-format-on-save nil t)))
  ;; eglot server 注册 + nixd 初始化选项
  ;; nixd 补全需要 initializationOptions 告诉它 nixpkgs 在哪 (默认空 → 无补全)。
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 (cons 'nix-mode
                       '("nixd"
                         :initializationOptions
                         (:nixpkgs (:expr "import <nixpkgs> {}")
                          :formatting (:provider "nixfmt")))))))

(provide 'init-nix)
;;; init-nix.el ends here