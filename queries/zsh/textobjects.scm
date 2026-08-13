;; extends
;; ---------------------------------------------------------------------------
;; zsh text objects — additions only. `;; extends` above is load-bearing: without
;; it this file REPLACES nvim-treesitter-textobjects' zsh query rather than adding
;; to it, and @function/@loop/@conditional/@comment/@assignment would all quietly
;; stop working.
;;
;; Upstream's zsh query defines 14 captures but neither @block nor
;; @parameter.outer, so of the objects mapped in lua/plugins/treesitter.lua,
;; `ab`/`ib` and `aa` were silent no-ops in every shell buffer. (`ac`/`ic` and
;; ]] [[ ][ [] stay no-ops on purpose — shell has no class, and mapping them to
;; something arbitrary would be worse than nothing.)
;;
;;   @block      a { … } body or a do … done body        ab  ib
;;   @parameter  an argument to a command                 aa  (ia is upstream's)
;; ---------------------------------------------------------------------------

;; A brace block. This also matches a function body, which upstream separately
;; captures as @function.inner — deliberate, and how the other languages behave:
;; inside `f() { … }`, `af` takes the function and `ab` takes just the braces.
(compound_statement) @block.outer

(compound_statement
  .
  "{"
  _+ @block.inner
  "}")

;; The do … done half of for/while/until. Upstream captures the whole statement
;; as @loop.outer, so `al` gives `for x in …; do … done` while `ab` gives only the
;; body — the same split as @function.outer vs @block.outer above.
(do_group) @block.outer

(do_group
  .
  "do"
  _+ @block.inner
  "done")

;; Arguments. Upstream has @parameter.inner for (word) only; this adds the outer
;; form and widens it to any argument node, so `aa` also works on a quoted string
;; or a variable ref -- `git commit -m "msg"` should treat "msg" as an argument.
(command
  argument: (_) @parameter.outer)
