# AGENT.md

## Goal

Add a text-only chat buffer workflow to `chatgpt-el`.

The new workflow should keep browser input/output hidden behind the existing
CDP bridge, while the user interacts with a dedicated Emacs buffer. The buffer
should show both submitted queries and finalized responses. In-progress browser
polling should use temporary/raw buffers only; the visible chat buffer should be
updated only when the response is complete.

## Scope

- Add a dedicated chat command, tentatively `chatgpt-chat`.
- Add a dedicated major mode, tentatively `chatgpt-chat-mode`.
- Use a Markdown-oriented buffer for the visible conversation.
- Bind `C-c C-c` in the chat buffer to submit the current query.
- Insert the submitted query into the chat buffer before sending.
- Poll browser/CDP output in a temporary/raw buffer.
- Insert only the finalized assistant response into the chat buffer.
- Keep the existing `chatgpt-send`, `chatgpt-send-api`, and response-buffer
  workflow working.

## Non-Goals

- No streaming display in the visible chat buffer.
- No rich browser UI mirroring.
- No image, attachment, or non-text rendering support.
- No attempt to perfectly preserve ChatGPT/Gemini/Claude HTML formatting.
- No browser-side conversation management beyond the current active web page.

## Design

### Visible Chat Buffer

Use a stable buffer name such as:

```elisp
*chatgpt chat*
```

The buffer should contain a transcript in Markdown-like text:

```markdown
## User

What is continuation-passing style?

## Assistant

Continuation-passing style (CPS) is ...

## User

Show a small Emacs Lisp example.
```

The user should type the next query at the end of the buffer. Pressing
`C-c C-c` submits the text that belongs to the current unfinished `## User`
section.

### Mode Choice

Prefer deriving the chat mode from `markdown-mode` when it is available.
Fallback to `text-mode` if `markdown-mode` is not installed.

The mode should provide:

- `C-c C-c`: submit current query.
- `C-c C-k`: cancel current browser polling process, if any.
- Readable line wrapping via `visual-line-mode`.

### Query Boundary

Track the start of the current editable query with a buffer-local marker:

```elisp
(defvar-local chatgpt-chat--input-marker nil)
```

When opening the chat buffer or after inserting an assistant response, append:

```markdown
## User

```

Then set `chatgpt-chat--input-marker` to point after the blank line. On submit,
read from that marker to `point-max`, trim whitespace, and send that text.

### Submission Flow

1. User edits text after the current `## User` heading.
2. User presses `C-c C-c`.
3. Emacs reads the current query from `chatgpt-chat--input-marker`.
4. If the query is empty, show a message and do nothing.
5. Mark the visible chat buffer as waiting.
6. Send the query to the browser using the existing CDP path.
7. Poll the response in a raw temporary buffer.
8. When the response is complete, convert it to text/Markdown-ish content.
9. Append:

```markdown

## Assistant

<final response>

## User

```

10. Move point to the new input area.

The submitted query remains visible because it was already typed in the chat
buffer.

### Browser/CDP Reuse

Reuse the existing browser-side functions as much as possible:

- `chatgpt--start-browser`
- `chatgpt-prog`
- `chatgpt-cdp -e ENGINE -m MODEL`
- `chatgpt-cdp -e ENGINE -r`

Avoid changing `chatgpt-cdp` for the first implementation unless a small output
format flag becomes clearly useful.

### Raw Response Handling

Use a hidden/raw buffer for polling, similar to the current response monitor:

```elisp
*chatgpt chat raw*
```

The raw buffer may contain HTML plus the current `EOF` marker. The visible chat
buffer should never show raw HTML unless conversion fails.

### Response Completion

For the first implementation, reuse the existing completion heuristics:

- response ends with `\nEOF\n`, or
- unchanged response has been observed enough times.

This is already implemented in the current monitor path and can be adapted for
the chat buffer.

### HTML to Text/Markdown

Initial implementation:

1. Insert raw HTML into a temporary buffer.
2. Remove the trailing `EOF` marker.
3. Use `shr-render-region` to turn HTML into readable text.
4. Apply the existing cleanup rules from `chatgpt--monitor-format-buffer`, but
   avoid inserting the model header because the chat transcript already has
   `## Assistant`.

Future improvement:

- Add a Python-side `--text` or `--markdown` option to `chatgpt-cdp`.
- Use browser-side `innerText` rather than `innerHTML` for text-only mode.
- Keep code blocks more faithfully if the browser DOM exposes language labels.

## Implementation Plan

### Step 1: Add Chat Buffer Skeleton

- Add buffer-local variables:
  - `chatgpt-chat--input-marker`
  - `chatgpt-chat--engine`
  - `chatgpt-chat--model`
  - `chatgpt-chat--process`
  - `chatgpt-chat--monitor-process`
  - `chatgpt-chat--monitor-timer`
  - `chatgpt-chat--last-raw-response`
  - `chatgpt-chat--monitor-ntries`
- Add `chatgpt-chat-mode`.
- Add `chatgpt-chat` interactive command.
- Create/open `*chatgpt chat*`.
- Insert an initial `## User` section if the buffer is empty.
- Bind `C-c C-c` to a placeholder submit function.

### Step 2: Implement Query Submission

- Implement `chatgpt-chat-submit`.
- Extract query text from `chatgpt-chat--input-marker` to `point-max`.
- Reject empty query.
- Start browser if needed.
- Send query using `chatgpt-prog`.
- Store engine/model/process state in the chat buffer.
- Prevent duplicate submission while a request is active.

### Step 3: Implement Hidden Polling

- Add chat-specific monitor functions, likely copied and simplified from:
  - `chatgpt--start-monitor`
  - `chatgpt--monitor-event`
  - `chatgpt--monitor-process-sentinel`
- Poll into `*chatgpt chat raw*`.
- Do not modify the visible chat buffer until completion.
- Keep the raw buffer hidden from normal user workflow.

### Step 4: Insert Final Response

- Add `chatgpt-chat--raw-html-to-text`.
- Convert final raw HTML to readable text.
- Append `## Assistant` plus the final response.
- Append the next `## User` heading.
- Reset the input marker.
- Restore point to the new input area.
- Save the prompt/response pair using the existing logging style if practical.

### Step 5: Polish Mode Behavior

- Add `C-c C-k` cancellation.
- Update mode-line status while waiting and when idle.
- Make the current input area easy to find.
- Avoid accidental edits to previous transcript sections if this can be done
  simply. Do not over-engineer this in the first pass.

### Step 6: Documentation

- Update `README.md` with:
  - `M-x chatgpt-chat`
  - `C-c C-c` to submit
  - browser/CDP prerequisites
  - text-only/final-response-only behavior

## Suggested First Patch

Start with Step 1 only. This keeps the first change small and easy to verify:

- `M-x chatgpt-chat` opens `*chatgpt chat*`.
- The buffer is in `chatgpt-chat-mode`.
- The buffer contains:

```markdown
## User

```

- `C-c C-c` currently reports the query it would submit.

After that works, implement the actual send and hidden polling in separate
patches.

