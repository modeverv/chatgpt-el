;; -*- Emacs-Lisp -*-
;;
;; Interactively access generative AIs from Emacs with/without APIs.
;; Copyright (C) 2023-2025 Hiroyuki Ohsaki.
;; All rights reserved.
;;

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; Usage:
;; C-c b          Send a prompt near the point.
;; C-u C-c b      Send a prompt near the point after revising the prompt.
;; C-u C-u C-c b  Send a prompt near the point after selecting a prompt prefix.
;; C-c Q          Insert the latest response at the point.
;; C-u C-c Q      Insert the pair of the latest prompt and response at the point.
;; C-c f          Generate a context that fits at the point.
;; C-c E          Select AI engine.

(require 'shr)
(require 'subr-x)

;;; User Configuration

(defvar chatgpt-prog "~/src/chatgpt-el/chatgpt-cdp")
(defvar chatgpt-default-engine "chatgpt")

(defvar chatgpt-api-prog "~/src/chatgpt-el/chatgpt-api")
(defvar chatgpt-default-api-engine "ollama")

(defvar chatgpt-browser-prog "qutebrowser")
(defvar chatgpt-browser-args '("--qt-flag" "remote-debugging-port=9000"))
;; (defvar chatgpt-browser-prog "chromium")
;; (defvar chatgpt-browser-args '("--remote-debugging-port=9000"
;;                                "--remote-allow-origins=http://127.0.0.1:9000"))

(defvar chatgpt-prefix-alist
  '((?w . "Explain the following in Japanese with definition, pros, cons, examples, and issues:")
    (?s . "Summarize the following in Japanese in a plain academic writing style:")
    (?S . "Select interesting or noteworthy information from the following and present five items in a ranked list in Japanese:")
    (?j . "Translate the following in Japanese in a plain academic writing style:")
    (?e . "Translate the following in English in a plain academic writing style.  Output only the translation; do not output any text other than the translation:")
    (?f . "Format the following into a human-readable format (plain text):")
    (?p . "Proofread the following and provide a list of changes made in Markdown table:")
    (?r . "Rewrite the following in a plain academic writing style:")
    (?E . "Review and identify errors in the following document/program:")
    (?R . "Refactor the code starting from ----.  Do not delete any comment.  Add a short docstring for functions if missing. ----"))
  "Alist of prompt prefixes.")

(defvar chatgpt-model-alist
  '(("chatgpt" . "ChatGPT-5.5")
    ("gemini" . "Gemini-3")
    ("openwebui" . "gemma4:26b")
    ("claude" . "ClaudeSonnet-4.5")
    ("copilot" . "Copilot-Auto")
    ("copilot-enterprise" . "Copilot-Auto")
    ("perplexity" . "Perplexity-Auto")))

(defvar chatgpt-api-model-alist
  '(("chatgpt" . "gpt-5.4-mini")
    ("gemini" . "gemini-3-flash")
    ("ollama" . "gemma4:26b")))

;; (chatgpt--extract-models "model output\nfoo 1\nbar 2\n")

(defun chatgpt--extract-models (model-info)
  (let* ((lines (cdr (split-string model-info "\n" t))))
    (mapcar (lambda (line)
	      (car (split-string line "[ \t]+" t)))
	    lines)))

(defvar chatgpt-api-chatgpt-models
  (chatgpt--extract-models "\
model          output  intel  speed  cutoff
gpt-5-nano     $0.4    2      5      2024-05-31
gpt-5.4-nano   $1.25   2      5      2025-08-31
gpt-5-mini     $2      3      4      2024-05-31
o4-mini        $4.4    R4     3      2025-06-01
o3-mini        $4.4    R4     3      2024-10-01
gpt-5.4-mini   $4.5    3      4      2025-08-31
o3             $8      R5     2      2024-06-01
gpt-5.1        $10     4      4      2024-09-30
gpt-5.2        $14     4      4      2025-08-31
gpt-5.4        $15     5      4      2025-08-31
gpt-4o         $10     3      3      2023-10-01
gpt-4-turbo    $30     2      3      2023-12-01
o1             $60     R4     1      2023-10-01
gpt-5.4-pro    $90     5      2      2025-08-31
gpt-5.2-pro    $168    5      1      2025-08-31"))

(defvar chatgpt-api-gemini-models
  (chatgpt--extract-models "\
model                          output   input    speed        context
gemini-3.1-flash-lite-preview  $1.5     $0.25    Instant      1M
gemini-3.1-flash               $3       $0.5     Fastest      1M
gemini-2.5-flash               $2.5     $0.3     Fast         2M
gemini-3.1-pro-preview         $12* $2* Variable** 1M
gemini-2.5-pro                 $10      $1.25    Medium       2M
imagen-4.0-fast                $0.02    n/a      Fast         n/a
imagen-4.0-standard            $0.04    n/a      Medium       n/a
gemini-3.1-flash-image-preview $0.067   $0.25    Fast         128k
gemini-3-pro-image-preview     $0.134   $2       Medium       65k"))

(defvar chatgpt-api-ollama-models
  (chatgpt--extract-models "\
NAME                      ID              SIZE      MODIFIED    
gpt-oss:20b               17052f91a42e    13 GB     2 days ago     
qwen3.5-limited:latest    a9b999f6970c    17 GB     2 weeks ago    
qwen3.5:27b               7653528ba5cb    17 GB     2 weeks ago    
kimi-k2.5:cloud           6d1c3246c608    -         2 weeks ago    
gemma4:31b                6316f0629137    19 GB     2 weeks ago    
gemma4:e4b                c6eb396dbd59    9.6 GB    2 weeks ago    
gemma4:26b                5571076f3d70    17 GB     2 weeks ago    
"))

(defvar chatgpt-api-models-alist
  '(("chatgpt" . chatgpt-api-chatgpt-models)
    ("gemini" . chatgpt-api-gemini-models)
    ("ollama" .  chatgpt-api-ollama-models)))

;;; Internal Variables (Buffer Local)

(defvar chatgpt--last-buf nil)
;; Make variables buffer-local to support parallel execution across different buffers.
(defvar-local chatgpt--engine nil)
(defvar-local chatgpt--model nil)
(defvar-local chatgpt--use-api nil)
(defvar-local chatgpt--process nil)
(defvar-local chatgpt--prompt nil)
(defvar-local chatgpt--monitor-process nil)
(defvar-local chatgpt--monitor-timer nil)
(defvar-local chatgpt--monitor-ntries 0)
(defvar-local chatgpt--last-raw-response nil)

(defvar chatgpt-chat-buffer-name "*chatgpt chat*")
(defvar chatgpt-chat-raw-buffer-name "*chatgpt chat raw*")
(defvar chatgpt-chat-progress-buffer-name "*chatgpt chat progress*")
(defvar chatgpt-chat-progress-window-height 12)

(defvar-local chatgpt-chat--input-marker nil)
(defvar-local chatgpt-chat--engine nil)
(defvar-local chatgpt-chat--model nil)
(defvar-local chatgpt-chat--process nil)
(defvar-local chatgpt-chat--monitor-process nil)
(defvar-local chatgpt-chat--monitor-timer nil)
(defvar-local chatgpt-chat--last-raw-response nil)
(defvar-local chatgpt-chat--monitor-ntries 0)
(defvar-local chatgpt-chat--waiting nil)
(defvar-local chatgpt-chat--last-prompt nil)
(defvar-local chatgpt-chat--conversation-url nil)

(defvar chatgpt-font-lock-keywords
  '(("^[;%].+" . font-lock-comment-face)
    ("^#+.+" . font-lock-function-name-face)
    ("^Q\\. .+" . font-lock-function-name-face)
    ("^\\S.+?[:：]$" . font-lock-function-name-face)
    ("\\*\\*[^*]+\\*\\*" . font-lock-constant-face)
    ("^ *[0-9.]+ " . font-lock-type-face)
    ("^ *[*-] .*$" . font-lock-string-face)
    ("[A-Z_]\\{3,\\}" . font-lock-constant-face)
    ("【.+?】" . font-lock-constant-face)
    ("「.+?」" . font-lock-constant-face)
    ("\".+?\"" . font-lock-string-face)
    ("'.+?'" . font-lock-string-face)))

;;; Mode Definition

(define-derived-mode chatgpt-mode text-mode "ChatGPT"
  "Major mode for ChatGPT response."
  (setq font-lock-defaults '(chatgpt-font-lock-keywords 'keywords-only nil))
  (font-lock-mode 1)
  (visual-line-mode 1))

(defvar chatgpt-chat-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") 'chatgpt-chat-submit)
    (define-key map (kbd "C-c C-k") 'chatgpt-chat-cancel)
    map)
  "Keymap for `chatgpt-chat-mode'.")

(eval
 `(define-derived-mode chatgpt-chat-mode
    ,(if (fboundp 'markdown-mode) 'markdown-mode 'text-mode)
    "ChatGPT-Chat"
    "Major mode for a text-only ChatGPT conversation buffer."
    (visual-line-mode 1)
    (setq-local comment-start "<!-- ")
    (setq-local comment-end " -->")))
(declare-function chatgpt-chat-mode nil)

(defun chatgpt--update-mode-name (status)
  "Update the mode name to reflect the current status."
  (setq mode-name (format "%s %s" chatgpt--model status))
  (force-mode-line-update))

(defun chatgpt-chat--update-mode-name (status)
  "Update the chat buffer mode name to reflect STATUS."
  (setq mode-name (format "ChatGPT-Chat %s" status))
  (force-mode-line-update))

;;; Buffer Management

(defun chatgpt--buffer-name (engine model use-api &optional raw)
  "Generate buffer name based on ENGINE, MODEL and USE-API."
  (format "*%s%s %s*"
          engine
          (if use-api "-api" "")
          (if raw "raw" "response")))

(defun chatgpt--get-buffer-create (engine model use-api &optional raw)
  "Get or create a buffer for the specific ENGINE, MODEL and API usage."
  (let ((buf-name (chatgpt--buffer-name engine model use-api raw)))
    (get-buffer-create buf-name)))

(defun chatgpt--init-buffer (engine model use-api)
  "Initialize the response buffer with local variables."
  (let ((buf (chatgpt--get-buffer-create engine model use-api)))
    (with-current-buffer buf
      (let ((proc (get-buffer-process buf)))
        (when (processp proc)
          (set-process-sentinel proc nil)
          (delete-process proc)))
      (chatgpt-mode)
      ;; Set local variables specific to this execution context.
      (setq chatgpt--engine engine)
      (setq chatgpt--model model)
      (setq chatgpt--use-api use-api)
      (chatgpt--update-mode-name "streaming")
      (erase-buffer)
      ;; Display in the other window
      (delete-other-windows)
      (split-window)
      (set-window-buffer (next-window) buf))
    buf))

(defun chatgpt-chat--ensure-input-section ()
  "Ensure the chat buffer has a current user input section."
  (unless (markerp chatgpt-chat--input-marker)
    (setq chatgpt-chat--input-marker (make-marker)))
  (when (= (point-min) (point-max))
    (insert "# Session\n\n- URL: \n\n## User\n\n")
    (set-marker chatgpt-chat--input-marker (point)))
  (save-excursion
    (goto-char (point-min))
    (unless (looking-at-p "# ")
      (insert "# Session\n\n- URL: \n\n")))
  (unless (marker-position chatgpt-chat--input-marker)
    (goto-char (point-max))
    (if (re-search-backward "^## User\n\n" nil t)
        (set-marker chatgpt-chat--input-marker (match-end 0))
      (goto-char (point-max))
      (unless (bolp)
        (insert "\n"))
      (insert "\n## User\n\n")
      (set-marker chatgpt-chat--input-marker (point)))))

(defun chatgpt-chat--sync-default-engine ()
  "Sync the chat buffer engine/model from the current Web defaults."
  (unless (chatgpt-chat--active-p)
    (setq chatgpt-chat--engine chatgpt-default-engine)
    (setq chatgpt-chat--model
          (cdr (assoc chatgpt-chat--engine chatgpt-model-alist)))))

(defun chatgpt-chat--get-buffer ()
  "Return the chat buffer, creating and initializing it as needed."
  (let ((buf (get-buffer-create chatgpt-chat-buffer-name)))
    (with-current-buffer buf
      (unless (derived-mode-p 'chatgpt-chat-mode)
        (chatgpt-chat-mode))
      (chatgpt-chat--sync-default-engine)
      (chatgpt-chat--ensure-input-section)
      (chatgpt-chat--update-mode-name (if chatgpt-chat--waiting "waiting" "idle")))
    buf))

(defun chatgpt-chat--set-session-url (url)
  "Record URL in the chat buffer's Session section."
  (setq chatgpt-chat--conversation-url url)
  (when (and url (not (string-empty-p url)))
    (save-excursion
      (chatgpt-chat--ensure-input-section)
      (goto-char (point-min))
      (let ((section-end (save-excursion
                           (if (re-search-forward "^## " nil t)
                               (match-beginning 0)
                             (point-max)))))
        (if (re-search-forward "^- URL:.*$" section-end t)
            (replace-match (concat "- URL: " url) t t)
          (goto-char (point-min))
          (forward-line 1)
          (insert "\n- URL: " url "\n"))))))

;;; Utilities

(defun chatgpt--replace-regexp (regexp newtext)
  "Replace REGEXP with NEWTEXT in the current buffer."
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward regexp nil t)
      (replace-match newtext))))

(defun chatgpt--expand-macros ()
  "Expand macros in the current buffer."
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "\\[\\[\\([^]]+\\)\\]\\]" nil t)
      (let ((filename (match-string 1)))
        (when (file-exists-p filename)
          (replace-match "")
          (insert-file-contents filename))))))

(defun chatgpt--find-prompt ()
  "Find the prompt based on the current point or selected region."
  (let (beg end prompt)
    (cond
     (mark-active
      (setq beg (region-beginning) end (region-end)
            prompt (buffer-substring-no-properties beg end)))
     ((looking-at "\\w")
      (setq prompt (thing-at-point 'word)))
     (t
      (setq prompt (string-trim (or (thing-at-point 'paragraph) "")))))
    (replace-regexp-in-string "^Q\\. *" "" prompt)))

(defun chatgpt--port-listening-p (host port)
  (let ((connected nil))
    (condition-case nil
	(let ((proc (open-network-stream "chatgpt" nil host port)))
          (setq connected t)
          (delete-process proc))
      (error nil))
    connected))

(defun chatgpt--start-browser ()
  "Start web browser if not running."
  (unless chatgpt--use-api
      (unless (chatgpt--port-listening-p "localhost" 9000)
        (apply 'start-process chatgpt-browser-prog nil
	       chatgpt-browser-prog chatgpt-browser-args)
          (while (not (chatgpt--port-listening-p "localhost" 9000))
            (sleep-for .5)))))

;;; Process Handling (Send & Receive)

(defun chatgpt--send-prompt (prompt engine model use-api)
  "Send PROMPT to the AI using specified configuration."
  (let ((buf (chatgpt--init-buffer engine model use-api)))

    (with-current-buffer buf
      (chatgpt--stop-monitor) ;; Stop existing monitor in THIS buffer
      (chatgpt--start-monitor)

      (when (and chatgpt--process (process-live-p chatgpt--process))
        (kill-process chatgpt--process))

      (chatgpt--start-browser)

      (let* ((prog (if use-api chatgpt-api-prog chatgpt-prog))
             (args (list "-e" engine "-m" model))
             (proc (apply 'start-process engine buf prog args))
	     (encoded-prompt (encode-coding-string prompt 'utf-8)))
	(setq chatgpt--process proc)
        (process-send-string proc (concat encoded-prompt "\n"))
	(process-send-eof proc))
	
      (set-process-filter chatgpt--process 'chatgpt--process-filter)
      (set-process-sentinel chatgpt--process 'chatgpt--process-sentinel)
      (setq chatgpt--prompt prompt)
      (setq chatgpt--last-buf buf))))

(defun chatgpt--process-filter (proc string)
  "Process the output STRING from the process PROC."
  (when (buffer-live-p (process-buffer proc))
    (with-current-buffer (process-buffer proc)
      (save-excursion
        (goto-char (point-max))
        (insert string)
        ;; Hide emphasis tags.
        (goto-char (point-min))
        (while (re-search-forward "\\(\\*\\*\\).+?\\(\\*\\*\\)" nil t)
          (put-text-property (match-beginning 1) (match-end 1) 'invisible t)
          (put-text-property (match-beginning 2) (match-end 2) 'invisible t))))))

(defun chatgpt--process-sentinel (proc event)
  "Handle the completion EVENT of the process PROC."
  (when (and (buffer-live-p (process-buffer proc))
             (string-match "finished" event))
    (with-current-buffer (process-buffer proc)
      (if chatgpt--use-api (chatgpt--response-finished)))))

(defun chatgpt--response-finished ()
  "Handle the completion of a prompt."
  (chatgpt--update-mode-name "finished")
  (chatgpt--save))

(defun chatgpt--save ()
  "Save the last prompt and response."
  (let* ((save-silently t)
	 (tstamp (format-time-string "%y%m%d-%H%M%S"))
         (base (format "~/var/log/chatgpt/%s-%s" chatgpt--engine tstamp))
	 (prompt chatgpt--prompt)
	 (response (buffer-string)))
      (with-temp-buffer
        (insert prompt)
        (write-region (point-min) (point-max) (concat base ".pt")))
      (with-temp-buffer
        (insert response)
        (write-region (point-min) (point-max) (concat base ".rs")))))

;;; Monitor (Polling) Implementation

(defun chatgpt--start-monitor ()
  "Start monitoring response."
  (unless chatgpt--use-api
    (setq chatgpt--monitor-ntries 0)
    (chatgpt--sched-monitor-event)))

(defun chatgpt--stop-monitor ()
  "Stop the response monitoring process."
  (when (and chatgpt--monitor-timer (timerp chatgpt--monitor-timer))
    (cancel-timer chatgpt--monitor-timer)
    (setq chatgpt--monitor-timer nil))
  (when (and chatgpt--monitor-process (process-live-p chatgpt--monitor-process))
    (kill-process chatgpt--monitor-process)))

(defun chatgpt--sched-monitor-event ()
  "Schedule a monitoring event."
  ;; Pass the current buffer to the timer so it runs in correct context.
  (setq chatgpt--monitor-timer
        (run-with-timer .2 nil 'chatgpt--monitor-event (current-buffer))))

(defun chatgpt--monitor-event (buf)
  "Monitor the response from the AI."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (let ((raw-buf (chatgpt--get-buffer-create chatgpt--engine chatgpt--model nil t))
	    (engine chatgpt--engine))
        (with-current-buffer raw-buf
          (erase-buffer)
          (let* ((default-directory (expand-file-name "~"))
		 (proc (start-process "chatgpt-monitor" raw-buf
                                     chatgpt-prog "-e" engine "-r")))
	    (setq chatgpt--monitor-process proc)
            ;; Save the target response buffer in the process object for the sentinel
            (process-put proc 'target-buffer buf)
            (set-process-sentinel proc 'chatgpt--monitor-process-sentinel)))))))

(defun chatgpt--monitor-format-buffer ()
  "Format the contents of the response buffer."
  (goto-char (point-min))
  (insert (format "[%s]\n" chatgpt--model))
  (chatgpt--monitor-cleanup-buffer))

(defun chatgpt--monitor-cleanup-buffer ()
  "Apply common cleanup rules to rendered response text."
  (chatgpt--replace-regexp "\n\n\\( *[0-9-] .+?\\)$" "\n\\1")
  (chatgpt--replace-regexp "\\*\\*\\(.+?\\)\\*\\*" "\\1")
  (chatgpt--replace-regexp "’" "'")
  (chatgpt--replace-regexp "—" "---")
  (chatgpt--replace-regexp "–" "-")
  (chatgpt--replace-regexp "^Edit in a page$" "")
  (chatgpt--replace-regexp "^SVG Image\n" ""))

(defun chatgpt--monitor-process-sentinel (proc event)
  "Handle the completion EVENT of the monitor process PROC."
  (when (string-match-p "finished" event)
    (let ((buf (process-get proc 'target-buffer)))
      (when (buffer-live-p buf)
        (with-current-buffer buf
          (let ((response (with-current-buffer (process-buffer proc) (buffer-string))))
            (if (string= response chatgpt--last-raw-response)
                (setq chatgpt--monitor-ntries (1+ chatgpt--monitor-ntries))
              ;; Content updated.
              (let* ((win (get-buffer-window buf))
                     (last-pnt (if win (window-point win)))
                     (last-start (if win (window-start win))))
                (erase-buffer)
                (insert response)
                (shr-render-region (point-min) (point-max))
                (chatgpt--monitor-format-buffer)
                (when win
                  (set-window-point win last-pnt)
                  (set-window-start win last-start))
                (setq chatgpt--last-raw-response response)
                (setq chatgpt--monitor-ntries 0)))

            (if (or (string-suffix-p "\nEOF\n" response)
                    (>= chatgpt--monitor-ntries 50))
                (chatgpt--response-finished)
                (chatgpt--sched-monitor-event))))))))

;;; Chat Buffer Workflow

(defun chatgpt-chat--current-query ()
  "Return the current chat query text."
  (unless (and (markerp chatgpt-chat--input-marker)
               (marker-position chatgpt-chat--input-marker))
    (chatgpt-chat--ensure-input-section))
  (string-trim
   (buffer-substring-no-properties chatgpt-chat--input-marker (point-max))))

(defun chatgpt-chat--active-p ()
  "Return non-nil when the chat buffer is waiting for a response."
  (or chatgpt-chat--waiting
      (and chatgpt-chat--process
           (process-live-p chatgpt-chat--process))
      (and chatgpt-chat--monitor-process
           (process-live-p chatgpt-chat--monitor-process))
      (and chatgpt-chat--monitor-timer
           (timerp chatgpt-chat--monitor-timer))))

(defun chatgpt-chat--stop-monitor ()
  "Stop the chat response monitoring process."
  (when (and chatgpt-chat--monitor-timer (timerp chatgpt-chat--monitor-timer))
    (cancel-timer chatgpt-chat--monitor-timer)
    (setq chatgpt-chat--monitor-timer nil))
  (when (and chatgpt-chat--monitor-process
             (process-live-p chatgpt-chat--monitor-process))
    (kill-process chatgpt-chat--monitor-process)))

(defun chatgpt-chat-cancel ()
  "Cancel the current chat browser polling process, if any."
  (interactive)
  (when (and chatgpt-chat--process (process-live-p chatgpt-chat--process))
    (kill-process chatgpt-chat--process))
  (chatgpt-chat--stop-monitor)
  (setq chatgpt-chat--process nil)
  (setq chatgpt-chat--monitor-process nil)
  (setq chatgpt-chat--waiting nil)
  (chatgpt-chat--update-mode-name "idle")
  (chatgpt-chat--finish-progress "canceled" chatgpt-chat--last-raw-response)
  (message "ChatGPT chat request canceled."))

(defun chatgpt-chat--sched-monitor-event ()
  "Schedule a chat monitoring event."
  (setq chatgpt-chat--monitor-timer
        (run-with-timer .2 nil 'chatgpt-chat--monitor-event (current-buffer))))

(defun chatgpt-chat--start-monitor ()
  "Start hidden polling for the chat response."
  (setq chatgpt-chat--monitor-ntries 0)
  (setq chatgpt-chat--last-raw-response nil)
  (chatgpt-chat--show-progress "sending" nil)
  (chatgpt-chat--sched-monitor-event))

(defun chatgpt-chat--progress-buffer ()
  "Return the chat progress buffer."
  (let ((buf (get-buffer-create chatgpt-chat-progress-buffer-name))
        (model chatgpt-chat--model))
    (with-current-buffer buf
      (unless (derived-mode-p 'chatgpt-mode)
        (chatgpt-mode))
      (setq chatgpt--model model)
      (chatgpt--update-mode-name "waiting"))
    buf))

(defun chatgpt-chat--display-progress-buffer (buf)
  "Display progress BUF in a small side window without selecting it."
  (display-buffer-in-side-window
   buf
   `((side . bottom)
     (slot . 1)
     (window-height . ,chatgpt-chat-progress-window-height))))

(defun chatgpt-chat--show-progress (status raw-response)
  "Show chat progress STATUS and optional RAW-RESPONSE in a small buffer."
  (let ((buf (chatgpt-chat--progress-buffer))
        (model chatgpt-chat--model))
    (with-current-buffer buf
      (let ((inhibit-read-only t)
            (win (get-buffer-window buf)))
        (let ((last-pnt (and win (window-point win)))
              (last-start (and win (window-start win))))
          (erase-buffer)
          (if (string-empty-p (or raw-response ""))
              (insert (format "[%s] %s\n\nWaiting for browser response..."
                              model status))
            (insert raw-response)
            (goto-char (point-max))
            (when (re-search-backward "\nEOF\n\\'" nil t)
              (replace-match "\n"))
            (condition-case nil
                (shr-render-region (point-min) (point-max))
              (error
               (chatgpt--replace-regexp "<[^>]+>" "")))
            (chatgpt--monitor-cleanup-buffer)
            (goto-char (point-min))
            (insert (format "[%s] %s\n" model status)))
          (goto-char (point-min))
          (when win
            (set-window-point win (or last-pnt (point-min)))
            (set-window-start win (or last-start (point-min)))))))
    (chatgpt-chat--display-progress-buffer buf)))

(defun chatgpt-chat--finish-progress (status raw-response)
  "Mark the chat progress buffer as finished with STATUS and RAW-RESPONSE."
  (chatgpt-chat--show-progress status raw-response))

(defun chatgpt-chat--hide-progress-window ()
  "Hide the visible chat progress window, if any."
  (when-let ((win (get-buffer-window chatgpt-chat-progress-buffer-name)))
    (delete-window win)))

(defun chatgpt-chat-submit ()
  "Submit the current query in the chat buffer."
  (interactive)
  (unless (derived-mode-p 'chatgpt-chat-mode)
    (user-error "This command must be used in a chatgpt chat buffer"))
  (if (chatgpt-chat--active-p)
      (message "ChatGPT chat is still waiting for a response.")
    (progn
      (chatgpt-chat--sync-default-engine)
      (let* ((query (chatgpt-chat--current-query))
             (engine (or chatgpt-chat--engine chatgpt-default-engine))
             (model (or chatgpt-chat--model
                        (cdr (assoc engine chatgpt-model-alist)))))
        (if (string-empty-p query)
            (message "No query to submit.")
          (setq chatgpt-chat--engine engine)
          (setq chatgpt-chat--model model)
          (setq chatgpt-chat--last-prompt query)
          (setq chatgpt-chat--waiting t)
          (chatgpt-chat--update-mode-name "waiting")
          (chatgpt-chat--show-progress "starting browser" nil)
          (condition-case err
              (progn
                (chatgpt--start-browser)
                (let* ((proc (start-process "chatgpt-chat-send" nil
                                            chatgpt-prog "-e" engine "-m" model))
                       (encoded-query (encode-coding-string query 'utf-8)))
                  (setq chatgpt-chat--process proc)
                  (process-put proc 'target-buffer (current-buffer))
                  (set-process-sentinel proc 'chatgpt-chat--send-process-sentinel)
                  (process-send-string proc (concat encoded-query "\n"))
                  (process-send-eof proc))
                (chatgpt-chat--stop-monitor)
                (chatgpt-chat--start-monitor)
                (message "ChatGPT chat submitted."))
            (error
             (setq chatgpt-chat--waiting nil)
             (chatgpt-chat--update-mode-name "idle")
             (chatgpt-chat--finish-progress
              (format "failed: %s" (error-message-string err)) nil)
             (signal (car err) (cdr err)))))))))

(defun chatgpt-chat--send-process-sentinel (proc event)
  "Handle completion EVENT for the chat send process PROC."
  (unless (or (string-match-p "finished" event)
              (string-match-p "exited abnormally with code 0" event))
    (let ((buf (process-get proc 'target-buffer)))
      (when (buffer-live-p buf)
        (with-current-buffer buf
          (message "ChatGPT chat send process: %s" (string-trim event)))))))

(defun chatgpt-chat--monitor-event (buf)
  "Monitor the hidden browser response for chat buffer BUF."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (setq chatgpt-chat--monitor-timer nil)
      (let ((raw-buf (get-buffer-create chatgpt-chat-raw-buffer-name))
            (engine chatgpt-chat--engine))
        (with-current-buffer raw-buf
          (erase-buffer))
        (let* ((default-directory (expand-file-name "~"))
               (proc (start-process "chatgpt-chat-monitor" raw-buf
                                    chatgpt-prog "-e" engine "-r")))
          (setq chatgpt-chat--monitor-process proc)
          (process-put proc 'target-buffer buf)
          (set-process-sentinel
           proc 'chatgpt-chat--monitor-process-sentinel))))))

(defun chatgpt-chat--monitor-process-sentinel (proc event)
  "Handle completion EVENT for the chat monitor process PROC."
  (when (string-match-p "finished" event)
    (let ((buf (process-get proc 'target-buffer)))
      (when (buffer-live-p buf)
        (with-current-buffer buf
          (let ((response (with-current-buffer (process-buffer proc)
                            (buffer-string))))
            (if (string= response chatgpt-chat--last-raw-response)
                (setq chatgpt-chat--monitor-ntries
                      (1+ chatgpt-chat--monitor-ntries))
              (setq chatgpt-chat--last-raw-response response)
              (setq chatgpt-chat--monitor-ntries 0))
            (chatgpt-chat--show-progress
             (if (string-empty-p response)
                 "waiting"
               (format "receiving%s"
                       (if (> chatgpt-chat--monitor-ntries 0)
                           (format " unchanged:%d" chatgpt-chat--monitor-ntries)
                         "")))
             response)
            (if (or (string-suffix-p "\nEOF\n" response)
                    (and (not (string-empty-p response))
                         (>= chatgpt-chat--monitor-ntries 50)))
                (chatgpt-chat--response-finished response)
              (chatgpt-chat--sched-monitor-event))))))))

(defun chatgpt-chat--raw-html-to-text (raw)
  "Convert RAW browser HTML into readable text for the chat buffer."
  (with-temp-buffer
    (insert raw)
    (goto-char (point-max))
    (when (re-search-backward "\nEOF\n\\'" nil t)
      (replace-match "\n"))
    (condition-case nil
        (shr-render-region (point-min) (point-max))
      (error
       (chatgpt--replace-regexp "<[^>]+>" "")))
    (chatgpt--monitor-cleanup-buffer)
    (string-trim (buffer-string))))

(defun chatgpt-chat--fetch-current-url ()
  "Return the current browser URL for the chat engine, or nil on failure."
  (condition-case nil
      (with-temp-buffer
        (let ((status (call-process chatgpt-prog nil t nil
                                    "-e" chatgpt-chat--engine "-u")))
          (when (zerop status)
            (let ((url (string-trim (buffer-string))))
              (unless (string-empty-p url)
                url)))))
    (error nil)))

(defun chatgpt-chat--append-response (response)
  "Append finalized assistant RESPONSE and prepare the next user section."
  (goto-char (point-max))
  (unless (bolp)
    (insert "\n"))
  (insert "\n## Assistant\n\n")
  (insert (if (string-empty-p response)
              "(No response text was returned.)"
            response))
  (insert "\n\n## User\n\n")
  (unless (markerp chatgpt-chat--input-marker)
    (setq chatgpt-chat--input-marker (make-marker)))
  (set-marker chatgpt-chat--input-marker (point))
  (goto-char (point)))

(defun chatgpt-chat--save (response)
  "Save the last chat prompt and RESPONSE using the existing log style."
  (condition-case nil
      (let* ((save-silently t)
             (tstamp (format-time-string "%y%m%d-%H%M%S"))
             (base (format "~/var/log/chatgpt/%s-%s"
                           chatgpt-chat--engine tstamp))
             (prompt chatgpt-chat--last-prompt))
        (with-temp-buffer
          (insert (or prompt ""))
          (write-region (point-min) (point-max) (concat base ".pt")))
        (with-temp-buffer
          (insert response)
          (write-region (point-min) (point-max) (concat base ".rs"))))
    (error nil)))

(defun chatgpt-chat--response-finished (raw-response)
  "Finalize RAW-RESPONSE and append it to the visible chat buffer."
  (chatgpt-chat--stop-monitor)
  (let ((response (chatgpt-chat--raw-html-to-text raw-response))
        (url (chatgpt-chat--fetch-current-url)))
    (setq chatgpt-chat--waiting nil)
    (setq chatgpt-chat--process nil)
    (setq chatgpt-chat--monitor-process nil)
    (chatgpt-chat--set-session-url url)
    (chatgpt-chat--append-response response)
    (chatgpt-chat--save response)
    (chatgpt-chat--update-mode-name "idle")
    (chatgpt-chat--finish-progress "finished" raw-response)
    (chatgpt-chat--hide-progress-window)
    (message "ChatGPT chat response finished.")))

(defun chatgpt-chat ()
  "Open the text-only ChatGPT chat buffer."
  (interactive)
  (pop-to-buffer (chatgpt-chat--get-buffer))
  (goto-char (point-max)))

;;; Interactive Commands

(defun chatgpt-send (arg &optional use-api)
  "Send a prompt to the AI. With C-u, edit prompt. With C-u C-u, select
prefix."
  (interactive "P")
  (let* ((prefix "")
	 (engine (if use-api chatgpt-default-api-engine chatgpt-default-engine))
	 (model (cdr (assoc engine (if use-api chatgpt-api-model-alist chatgpt-model-alist))))
         (prompt (chatgpt--find-prompt)))
    (when arg
      (let* ((ch (read-char "Prefix [w]hat/[s]ummary/[S]ummary/[j]a/[e]n/[f]ormat/[p]roof/[r]ewrite/[E]rror/[R]efactor: "))
             (entry (assoc ch chatgpt-prefix-alist)))
        (setq prefix (cdr entry))))
    (with-temp-buffer
      (insert prompt)
      (chatgpt--expand-macros)
      (setq prompt (buffer-string)))
    (chatgpt--send-prompt (concat prefix prompt) engine model use-api)))

(defun chatgpt-send-api (arg)
  (interactive "P")
  (chatgpt-send arg t))

(defun chatgpt-insert-response (&optional arg)
  "Insert the latest response."
  (interactive "P")
  (let ((buf chatgpt--last-buf))
    (if (not (and buf (buffer-live-p buf)))
        (message "No active response buffer found.")
      (with-current-buffer buf
        (let ((prompt chatgpt--prompt)
              (response (string-trim (buffer-string))))
          (with-current-buffer (window-buffer (selected-window)) ;; Insert into original buffer.
            (if arg
                (insert "Q. " (or prompt "") "\n\nA. " response)
              (insert response))))))))

(defun chatgpt-fill ()
  "Guess a content that fits at the the point."
  (interactive)
  (let* ((pnt (point))
         (buf (buffer-string))
         (prefix "Appropriately fill in the __FILL_THIS_PART__ placeholder in the following document with the corresponding text or program.
If the document is a program, complete the code.
If it is a general document, complete the text.
If it is an email, compose a reply;
note that the sender's message is quoted with a leading '> '.
Write in the same language as the source document.
Output only the content to be inserted into __FILL_THIS_PART__.
Strictly exclude any other output.

---
")
	 (engine chatgpt-default-api-engine)
	 (model (cdr (assoc engine chatgpt-api-model-alist)))
         (prompt (concat (substring buf 0 (1- pnt))
			 "__FILL_THIS_PART__"
			 (substring buf (1- pnt)))))
    (chatgpt--send-prompt (concat prefix prompt) engine model t)))

;; (chatgpt-select-engine nil)
;; (chatgpt-select-engine t)
(defun chatgpt-select-engine (use-api)
  "Change the AI engine.  With the prefix argument USE-API, change the default
API engine; without ARG, change the default engine for Web."
  (interactive "P")
  (let* ((engine (if use-api chatgpt-default-api-engine chatgpt-default-engine))
	 (engines (map-keys (if use-api chatgpt-api-model-alist chatgpt-model-alist)))
	 (selected (completing-read (format "Select %sengine [%s]: "
					    (if use-api "API " "")
					    engine)
				    engines
				    nil t)))
    (when (not (string= selected ""))
      (if use-api
          (setq chatgpt-default-api-engine selected)
	(setq chatgpt-default-engine selected)
        (when-let ((buf (get-buffer chatgpt-chat-buffer-name)))
          (with-current-buffer buf
            (chatgpt-chat--sync-default-engine)
            (chatgpt-chat--update-mode-name
             (if chatgpt-chat--waiting "waiting" "idle"))))))))

;; (chatgpt-select-api-model)
(defun chatgpt-select-api-model ()
  (interactive)
  (let* ((engine chatgpt-default-api-engine)
	 (model (cdr (assoc engine chatgpt-api-model-alist)))
	 (all-models (symbol-value (cdr (assoc engine chatgpt-api-models-alist))))
	 (selected (completing-read (format "Select API model for %s [%s]: "
					    engine
					    model)
                                    all-models
				    nil t)))
    (when (not (string= selected ""))
      (setf (alist-get engine chatgpt-api-model-alist nil nil 'equal) selected))))

(provide 'chatgpt)
