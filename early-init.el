;;; -*- lexical-binding: t -*-
;;; early-init.el — 在 init.el 之前加载的最小启动配置
;;;
;;; 修复 native compilation:
;;; Emacs.app 自带的 libgccjit 会传 -mmacosx-version-min=18.0 给系统
;;; clang, 而 18.0 不是合法 macOS 版本号 (Apple 从 15 直接跳到 26),
;;; 导致每个 lisp 文件 native 编译失败。
;;; 修复: 用 native-comp-driver-options 覆盖为 26.0 (已验证 clang 接受)。
;;;
;;; 同时关闭 deferred / JIT 编译避免启动时刷屏。

(when (boundp 'native-comp-driver-options)
  (setq native-comp-driver-options '("-mmacosx-version-min=26.0")))
(when (boundp 'native-comp-deferred-compilation)
  (setq native-comp-deferred-compilation nil))
(when (boundp 'native-comp-jit-compilation)   ; Emacs 29 的旧变量名
  (setq native-comp-jit-compilation nil))
