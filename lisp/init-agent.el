;;; init-agent.el --- AI agent (agent-shell + Hermes ACP) -*- lexical-binding: t -*-

;;; Commentary:
;;
;; agent-shell (MELPA, 2026-09 装): 在原生 Emacs buffer 里跑 ACP (Agent Client
;; Protocol) agent。ACP 是 Zed 发起、多家编辑器/agent 共用的协议, agent-shell
;; 通过 acp.el 与 agent 进程用 stdio JSON-RPC 通信。
;;
;; Hermes 是 agent-shell 内置支持的 agent 之一 (agent-shell-hermes.el),
;; 默认命令就是 ("hermes" "acp") — 直接复用本机 ~/.hermes 的 provider/model/
;; memory/skills/tools 配置, 不需要额外登录。
;;
;; 界面: 对话流、工具活动、文件 diff (agent-shell-diff buffer, 可直接应用)、
;;       终端命令、审批弹窗, 全部在 Emacs 里渲染。
;;
;; 用法:
;;   C-c A            起一个 Hermes 新会话 (agent-shell-hermes-start-agent)
;;   M-x agent-shell  通用入口: 选其它 ACP agent (Claude Code/Gemini/Codex/...)
;;                    或恢复历史会话
;;   会话 buffer 内: C-c C-c 打断等, 完整键位见 M-x agent-shell-help-menu
;;
;; 注意: ACP 模式下 Hermes 跑精简工具集 hermes-acp (文件/终端/web/memory/
;;       skills/execute_code/delegate/vision), 不含消息平台投递和 cron 管理,
;;       /goal 在 ACP 里也不实现。要完整 CLI/TUI 功能就用 C-c v 开 vterm 跑 hermes。

;;; Code:

(use-package agent-shell
  :ensure t
  ;; 键位: C-c A 全局可用 (已实测 C-c a=org-agenda, C-c A 在 global 与
  ;; org-mode-map 里都空闲, 不会挤掉已有键)
  :bind ("C-c A" . agent-shell-hermes-start-agent)
  :init
  ;; 这两个 defcustom 定义在 agent-shell-hermes.el (按需加载), 这里用 setq 预设:
  ;; defcustom 只在变量未绑定时才设默认值, 所以预设值会生效。
  ;; 调起 Hermes ACP 服务端的命令 (hermes 在 PATH 上由 init-env.el 的
  ;; exec-path-from-shell 保证; 远程或换路径改这里)
  (setq agent-shell-hermes-acp-command '("hermes" "acp")
        ;; 文件改动审批: nil = 每次问; "accept_edits" = 工作区+/tmp 自动通过,
        ;; 只对 .git/.ssh/.env 这类敏感路径问; "dont_ask" = 整会话自动通过
        agent-shell-hermes-default-session-mode-id nil))

(provide 'init-agent)
;;; init-agent.el ends here
