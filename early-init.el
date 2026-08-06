;;; -*- lexical-binding: t -*-
;;; early-init.el — 在 init.el 之前加载的最小启动配置
;;;
;;; macOS 27 beta 下 native compilation 完全不可用:
;;; Emacs.app 的 libgccjit 传 -mmacosx-version-min=18.0 给系统 clang,
;;; 但 18.0 不是合法 macOS 版本号 (Apple 从 15 直接跳到 26),
;;; 导致所有 native 编译 (含 trampoline) 失败。
;;; trampoline 编译在子进程执行, native-comp-driver-options 无法传递,
;;; 只能完全关闭 native compilation, 退回字节码执行 (功能不受影响)。

;; 完全关闭 native compilation (速度设为 nil = 不编译)
(when (boundp 'native-comp-speed)
  (setq native-comp-speed nil))
(when (boundp 'comp-speed)                        ; 兼容旧变量名
  (setq comp-speed nil))
(when (boundp 'native-comp-deferred-compilation)
  (setq native-comp-deferred-compilation nil))
(when (boundp 'native-comp-jit-compilation)        ; JIT 编译
  (setq native-comp-jit-compilation nil))
