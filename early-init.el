;;; -*- lexical-binding: t -*-
;;; early-init.el — 在 init.el 之前加载的最小启动配置
;;;
;;; 禁用 deferred native compilation:
;;; Emacs.app (emacsformacosx) 自带的 libgccjit 会传 -mmacosx-version-min=18.0
;;; 给系统 clang, 而 18.0 不是合法 macOS 版本号 (Apple 从 15 直接跳到 26),
;;; 导致每个 lisp 文件 native 编译失败, 启动时刷屏
;;; "Warning (native-compiler): ... error invoking gcc driver"。
;;; 关闭后 Emacs 退回字节码执行, 功能不受影响。

(when (boundp 'native-comp-deferred-compilation)
  (setq native-comp-deferred-compilation nil))
(when (boundp 'native-comp-jit-compilation)   ; Emacs 29 的旧变量名
  (setq native-comp-jit-compilation nil))
