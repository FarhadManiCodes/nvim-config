;; extends
;; ---------------------------------------------------------------------------
;; SQL text objects — hand-written, because nvim-treesitter-textobjects ships
;; queries for 70-odd languages and sql is not one of them. Without this file
;; every ]m/[m/]M/[M motion and every af/ac/ab/aa/ai/al object defined in
;; lua/plugins/treesitter.lua is a silent no-op in a .sql buffer.
;;
;; SQL has no functions or classes in the C++/Python sense, so the mapping below
;; is chosen by ergonomics rather than by name:
;;
;;   @function     a statement — i.e. one query      ]m [m ]M [M   af  if
;;   @class        a BEGIN … END block               (see note)    ac  ic
;;   @block        a subquery or CTE body                          ab  ib
;;   @parameter    a column in a select list, or                   aa  ia
;;                 one argument of a call or definition
;;   @conditional  a CASE expression                               ai  ii
;;   @loop         a WHILE … LOOP                                  al  il
;;   @comment      -- line and /* block */ comments                a/
;;
;; NOTE on ]] [[ ][ []: Neovim's built-in ftplugin/sql.vim maps those four to a
;; regex BEGIN/END search, buffer-locally, and — unlike ftplugin/python.vim —
;; does NOT guard them behind g:no_plugin_maps. They therefore win over the
;; global maps, and @class here only drives ac/ic. Both mean "a BEGIN … END
;; block", so the two agree; the ftplugin's version just matches the keywords by
;; regex, including inside strings and comments.
;;
;; `inner` is deliberately absent where SQL has no body to speak of: `af` works
;; on any statement, but `if` only resolves inside a CREATE FUNCTION/PROCEDURE.

;; ── statements: the ]m/[m granularity ──────────────────────────────────────
;; Unanchored on purpose: at top level ]m steps the file's queries, and inside a
;; BEGIN … END block or a CREATE FUNCTION body it steps that body's statements.
;; The cost is that it also descends into a CTE's own statement — consistent
;; with the nesting rather than a special case, and af/if still bracket the
;; enclosing query from anywhere inside it.
(statement) @function.outer

(create_function (function_body) @function.inner)
(create_procedure (procedure_body) @function.inner)

;; ── BEGIN … END ────────────────────────────────────────────────────────────
(block) @class.outer
(block (statement) @class.inner)

;; ── subqueries and CTEs ────────────────────────────────────────────────────
(subquery) @block.outer
(cte) @block.outer
;; A cte wraps exactly one statement, so its inner is expressible; a subquery's
;; body is a sibling (select) + (from) pair with no node spanning both, and
;; there is no #make-range! directive available here to join them.
(cte (statement) @block.inner)

;; ── list items: select columns and call/definition arguments ───────────────
(select_expression (term) @parameter.outer @parameter.inner)
(invocation (term) @parameter.outer @parameter.inner)
(function_arguments (function_argument) @parameter.outer @parameter.inner)

;; ── CASE ───────────────────────────────────────────────────────────────────
(case) @conditional.outer
(case (when_clause) @conditional.inner)

;; ── WHILE … LOOP ───────────────────────────────────────────────────────────
(while_statement) @loop.outer
(while_statement (statement) @loop.inner)

;; ── comments ───────────────────────────────────────────────────────────────
(comment) @comment.outer
(marginalia) @comment.outer
