# NAME

chatgpt-el - access ChatGTP from Emacs without OpenAI API

![video](screenshot/video.gif)

# DESCRIPTION

**chatgpt-el** is an Emacs Lisp program designed to interactively
access ChatGPT (https://chat.openai.com/) from Emacs.  ChatGPT can be
easily accessed from a program using OpenAI API (e.g., using openai
module in the Python language), but accessing ChatGPT using OpenAI API
has several drawbacks.

1. Batch processing via OpenAI API is slow; Accessing OpenAI API
   sometimes takes a long time.  Such slow repsonse makes the
   experiences of accessing ChatGPT frustrating.

2. You must have a non-free OpenAI account with your credit card
   registration.  Frequently accessing ChatGPT may cost a lot, so that
   you have to keep watching your OpenAI billing record.

**chatgpt-el** solves the above issues by accessing ChatGPT from Emacs
without OpenAI API key.

**chatgpt-el** is implemented utlizing Chromium/Chrome browser's CDP
(Chrome DevTools Protocol)
(https://chromedevtools.github.io/devtools-protocol/), and therefore
it requires CDP-enabled Chromium/Chrom browser is running.
**chatgpt-el** operates by remotely controlling your instance of
Chromium/Chrome using the Node.js script called `chatgpt`, which is
built on Puppeteer library (https://pptr.dev/).  Therefore, your
Chromium/Chrom must accept CDP connections from `chatgpt` script.

![overview](overview.png)


Note that the implementation of **chatgpt** script depends on the
internal structure of the HTML file returned by the ChatGPT server.
If **chatgpt** does not work in your environment, you may need to
modifty **chatgpt** according to your einvironment.

# PREREQUISITES

- Chromium or Chrome browser supporting the CDP protocol.  Recent
  Chromium/Chrome browser supports the CDP protocol by default.

- Node.js (https://nodejs.org/en).

# INSTALLATION

``` sh
> git clone https://github.com/h-ohsaki/chatgpt-el
> git clone https://github.com/aslushnikov/getting-started-with-cdp.git
> cd getting-started-with-cdp
> npm i
> cd ../chatgpt-el
> sudo intall -m 644 chatgpt.el /usr/local/share/emacs/site-lisp
> ln -s ../getting-started-with-cdp/node_modules .
> cat <<EOF >>~/.emacs
;; chatgpt-el
(autoload 'chatgpt-send "chatgpt" nil t)
(autoload 'chatgpt-display-reply "chatgpt" nil t)
(global-set-key "\C-cq" 'chatgpt-send-region)
(global-set-key "\C-cQ" 'chatgpt-insert-reply)
(setq chatgpt-prog "../path/to/chatgpt-el/chatgpt")
EOF
```

You can place `chatgpt` script anywhere in your system, but several
Node.js modules such as Puppeteer must be accessible from `chatgpt`
program.

# USAGE

1. Start Chromium/Chrome browser with remote debugging on port 9000.

``` sh
> chromium --remote-debugging-port=9000
```

2. Visit ChatGPT (https://chat.openai.com/) in Chromium/Chrome, and
   login with your OpenAI account.

3. On Emacs, move the point (i.e., the cursor in Emacs) in or at the
   end of the paragraph of query sentence(s).  Alternatively, you can
   select the region containing query sentence(s).  Then, type `C-c q`
   or execute `M-x chatgpt-send`.

4. The query is automatically submitted to ChatGPT in your
   Chromium/Chrome.  The reply from ChatGPT will be displayed in
   another buffer in Emacs.

5. Once the reply is displayed, type `C-c Q` or execute M-x
   chatgpt-insert-reply from Emacs.  The reply from ChatGPT is
   inserted at the current point.

# TROUBLE SHOOTING

1. Make sure your Chromium/Chrome accepts CDP connection on
   localhost:9000.
   
``` sh
> telnet localhost 9000
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
GET /json/version HTTP/1.1

HTTP/1.1 200 OK
Content-Security-Policy:frame-ancestors 'none'
Content-Length:391
Content-Type:application/json; charset=UTF-8

{
   "Browser": "Chrome/112.0.5615.121",
   "Protocol-Version": "1.3",
   "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36",
   "V8-Version": "11.2.214.14",
   "WebKit-Version": "537.36 (@39cc...2268)",
   "webSocketDebuggerUrl": "ws:///devtools/browser/e32f...ca87"
}
```

2. Send a query using `chatgpt` script.

``` sh
> echo hello | ./chatgpt -s
```

You should see that `hello` is sent to ChatGPT in your Chromium/Chrome
browser.

3. Receive a reply using `chatgpt` script.

``` sh
> ./chatgpt -r
Hello! How can I assist you today?
```

This will show the reply from ChatGPT, which must be equivalent to
that shown in Chromium/Chrome.

# FOR QUTEBROWSER USERS

If you are a fan of qutebrowser instead of Chromium/Chrome browser,
you can use **qutechat** (https://github.com/h-ohsaki/qutechat), a
qutebrowser-version of **chatgpt-el**.
