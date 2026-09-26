;;; -*- lexical-binding: t -*-
;;; early-init.el — 在 init.el 之前加载的最小启动配置
;;;
;;; macOS 27 beta 下 native compilation 不可用:
;;; libgccjit 传 -mmacosx-version-min=18.0 给系统 clang (18.0 非法,
;;; Apple 从 15 跳到 26), 导致所有 native 编译失败。
;;; 关键: trampoline 编译在子进程执行, native-comp-speed 和
;;; native-comp-driver-options 都管不到子进程。
;;; 关闭 native-comp-enable-subr-trampolines 才能在 C 层面阻止
;;; trampoline 生成, 从根本上消除子进程调用。

;; 关闭 subr trampoline (C 层面, 父进程检查后不再 spawn 子进程)
(when (boundp 'native-comp-enable-subr-trampolines)
  (setq native-comp-enable-subr-trampolines nil))
(when (boundp 'comp-enable-subr-trampolines)     ; 别名
  (setq comp-enable-subr-trampolines nil))

;; 同时关闭其他 native compilation 通道
(when (boundp 'native-comp-speed)
  (setq native-comp-speed nil))
(when (boundp 'comp-speed)
  (setq comp-speed nil))
(when (boundp 'native-comp-deferred-compilation)
  (setq native-comp-deferred-compilation nil))
(when (boundp 'native-comp-jit-compilation)
  (setq native-comp-jit-compilation nil))

;; GC 调优 (2026-08-14): 默认 gc-cons-threshold 0.8MB, 加载大量包后触发
;; 过于频繁, GC 停顿是 org 文件打开 / 后台 agenda 计算卡顿的主因之一
;; (实测 gc-cons-percentage 0.6 后同操作耗时减半)。
(setq gc-cons-percentage 0.6)

;; 启动期优化 (2026-09-23, 3 轮实测 init 时间):
;;   基线              2.445s
;;   只放开 GC         2.265s  (-0.18)
;;   GC + 文件名处理    1.89s   (-0.57, -23%)
;; 大头不是 GC 而是 file-name-handler-alist: 启动期间每一次文件名操作
;; (require / load / expand-file-name ...) 都要把这个列表跑一遍。
;; gc-cons-threshold 设成最大后 gc-cons-percentage 会被忽略
;; (见它的 docstring), 所以启动期等于完全不 GC。
(defvar my/startup-file-name-handler-alist nil
  "启动前的 file-name-handler-alist, 供 after-init-hook 恢复。")
(setq my/startup-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(setq gc-cons-threshold most-positive-fixnum)

;; init 跑完必须恢复: 否则 TRAMP (C-x C-f /ssh:...) / 压缩包内文件 /
;; url-handler 之类的 handler 全部失效。
(add-hook 'after-init-hook
          (lambda ()
            (setq file-name-handler-alist my/startup-file-name-handler-alist)
            (setq gc-cons-threshold (* 32 1024 1024))))
