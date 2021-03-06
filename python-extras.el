;;; python-extras.el --- Extras for python-mode

;; Filename: python-extras.el
;; Description: Extras for python-mode
;; Author: Mickey Petersen (rot13 "zvpxrl@slrnu.bet")
;; Maintainer: Mickey Petersen
;; Copyright (C) 2010, Mickey Petersen, all rights reserved.
;; Created: 2010-05-22 21:21:04
;; Version: 0.2
;; Keywords: python utility refactor extras
;; Compatibility: GNU Emacs 23
;;
;; Features that might be required by this library:
;;
;; Emacs' built-in `python.el'.
;; Will not work with `python-mode.el' (yet)
;;

;;; This file is NOT part of GNU Emacs

;;; License
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; Random grab bag of extras for \\[python-mode] and
;; \\[inferior-python-mode].
;;
;; This package was made to improve Emacs' existing python mode,
;; `python.el'.  Unlike packages like ropemacs this module does not have
;; any mandatory external dependencies.
;;
;;
;; Several different helper functions were added to:
;;
;;  * Let you add parameters to the function block you're editing in
;;    using the minibuffer;
;;
;;  * Send the expression under point to either 'dir' or 'help' in
;;    inferior python without disrupting your current input.
;;
;;  * Add basic syntax highlighting to inferior python.
;;
;;  * Shift regions of code around and reindents according to the
;;    indentation depth of that block
;;
;;
;;;;;; How to use
;;
;; By default several commands are bound to various 'C-c' keybinds.
;;
;; In \\[python-mode]:
;;
;;; Misc
;;
;; <RET> - Now rebound to `newline-and-indent' -- as it should be.
;;
;; C-S-<up>/<down> - Shifts a region up/down intelligently,
;; reindenting as necessary.
;;
;;;; Refactor
;;
;; C-c C-p - Calls `python-mp-add-parameter' which will prompt you for
;; a parameter to add to the function point is currently in.  If you
;; are not in a function body an error is raised.
;;
;;
;;; Extract...
;;
;; Extracts the string/s-exp/expression at point to the top of the
;; current...
;;
;;   C-c C-e C-b - block
;;
;;   C-c C-e C-d - def
;;
;;   C-c C-e C-c - class
;;
;; In inferior python mode:
;;
;;; Inferior Python
;;
;; C-c C-d - Invokes `python-mp-send-dir'.  Sends a dir(EXPR) command
;; where EXPR is the expression at point.  It will preserve your
;; current input.
;;
;; C-d C-h - Invokes `python-mp-send-help'.  Sends a help(EXPR) command
;; where EXPR is the expressio nat point.  It will also preserve your
;; current input.
;;
;; Highlighting - Strings are now highlighted using a special "safety"
;; font locker to prevent the colors from 'bleeding'.
;;
;;
;;; Installation:
;;
;; Put `python-extras.el' somewhere in your `load-path'.
;;
;; Now add the following line to your .emacs or init.el:
;;
;; (require 'python-extras)
;;
;;

;;; Change log:
;; 2010/06/23
;;      * Added experimental replacement for python's default
;;        indentation function. The new function will automatically
;;        (but na�vely) reindent code blocks.
;;
;; 2010/06/18
;;      * Added extract to def/block/class
;;
;; 2010/06/06
;;      * Added `python-mp-shift-region-up/down'. Regions can
;;        now be moved around with C-S-<up> and C-S-<down>.
;;
;; 2010/06/02
;;      * Clarified the documentation and comments.
;;
;; 2010/05/24
;;      * Added typical Emacs GPL header.
;;
;;      * Introduced the first (of many?) font-lock additions to
;;        inferior python mode.
;;
;; 2010/05/22
;;      * Added `python-mp-send-help-at-pt'
;;
;; 2010/05/21
;;      * Begun work.
;;

;;; TODO
;;
;; Lots. `python-mp-add-parameter' works fine for pathological cases
;; but would probably fail if you have an esoteric coding style.
;;
;; I'm sure there are issues with the way i get the expression at
;; point. I use `thing-at-point' -- which is great -- but I have to
;; hack the syntax table. I'm sure there's a better way. And
;; `python.el' comes with something like it baked in; maybe find a way
;; of making it work with that?
;;
;; Add support for `python-mode.el', but that'll involve lots of
;; compatibility hacks or abusing defalias to map `python.el' to
;; `python-mode.el' bindings.
;;
;; I also need to add defcustom support; there's not a whole lot to
;; customize at this point but that's bound to change.
;;
;; Incorporate `Info-mode' help generation using
;; `comint-redirect-send-command-to-process'.
;;
;; Completion support with rlcompleter2
;;
;;

;;; Require

(require 'rx)
(require 'comint)
(require 'python)
(require 'thingatpt)
(require 'skeleton)

;;; Code:


;;; Keymaps

(define-key python-mode-map (kbd "C-c C-s") 'python-mp-send-and-switch)

;; refactoring
(define-key python-mode-map (kbd "C-c C-p") 'python-mp-add-parameter)
(define-key python-mode-map (kbd "C-c C-e C-d") 'python-mp-extract-to-def)
(define-key python-mode-map (kbd "C-c C-e C-c") 'python-mp-extract-to-class)
(define-key python-mode-map (kbd "C-c C-e C-b") 'python-mp-extract-to-block)

;; this really should be the default keybinding in Python.
(define-key python-mode-map (kbd "C-m") 'newline-and-indent)

;; smart quote functionality
;; (define-key python-mode-map ?\" 'python-mp-smart-quote)
;; (define-key python-mode-map ?\' 'python-mp-smart-quote)

;; region shifting and indentation modifications
(define-key python-mode-map (kbd "C-S-<up>") 'python-mp-shift-region-up)
(define-key python-mode-map (kbd "C-S-<down>") 'python-mp-shift-region-down)

(define-key python-mode-map (kbd "C-<") 'python-mp-indent-left)
(define-key python-mode-map (kbd "C->") 'python-mp-indent-right)
;;(define-key python-mode-map (kbd "<tab>") 'python-mp-reindent)

;;; Keymaps for inferior python
(define-key inferior-python-mode-map (kbd "C-c C-h") 'python-mp-send-help)
(define-key inferior-python-mode-map (kbd "C-c C-d") 'python-mp-send-dir)
(define-key inferior-python-mode-map (kbd "C-c C-i") 'python-mp-send-mro)

(defconst python-mp-def-regexp (rx bol (0+ (any space)) "def")
  "Regular expression `python-mp-add-parameter' uses to match a
  function definition.")

(defconst python-mp-class-regexp (rx bol (0+ (any space)) "class")
  "Regular expression `python-mp-extract-to' uses to match a
  class definition.")

(defun python-mp-send-help ()
  "Sends a help(EXPR) command when called from an inferior python
buffer, where EXPR is an expression at Point."
  (interactive (if (eq major-mode 'inferior-python-mode)
                   (python-mp-compile-comint-query "help" (python-mp-get-expression-at-pt)))))

(defun python-mp-send-dir ()
  "Sends a dir(EXPR) command when called from an inferior python
buffer, where EXPR is an expression at Point."
  (interactive (if (eq major-mode 'inferior-python-mode)
                   (python-mp-compile-comint-query "dir" (python-mp-get-expression-at-pt)))))

(defun python-mp-send-mro ()
  "Queries the Python shell for the MRO (Method Resolution Order)
  information for the object on point."
  (interactive (if (eq major-mode 'inferior-python-mode)
                   (python-mp-send-arg
                    (concat "for ex in reversed(" (python-mp-get-expression-at-pt)
                            ".__mro__): print '{0:<15} {1:<10} ({2})'.format(ex.__name__, ex, ex.__doc__)\n\n")))))

(defun python-mp--build-py-func (func arg)
  "Internal function that builds a function call, FUNC, with ARG."
  )

(defun python-mp-get-expression-at-pt ()
  "Takes the word at point using a modified syntax table and
returns it."
  ;; we need a quick-and-dirty syntax table hack here to make
  ;; `thing-at-point' pick up on the fact that '.', '_', etc. are all
  ;; part of a single expression.
  (with-syntax-table (make-syntax-table)
    (modify-syntax-entry ?. "w")
    (modify-syntax-entry ?_ "w")
    ;; grab the word and return it
    (let ((word (thing-at-point 'word)))
      (if word
          word
        (error "Cannot find an expression at point")))))

(defun python-mp-compile-comint-query (func arg)
  "Sends a func(ARG) query to an `inferior-python-mode' process
using `python-mp-call-func-on-word'"
  ;(interactive "sFunc: \nsQuery: ")
  ;; this should only work in `inferior-python-mode'
  (if (and (eq major-mode 'inferior-python-mode)
           arg (stringp func) (stringp arg))
      (python-mp-send-arg (concat func "(" arg ")" "\n"))
    (error "Failed to send query")))

(defconst python-mp-from-statement-regexp "")

(defun python-mp-declare-import (module &optional identifier)
  "Not Yet Implemented. Introduces MODULE as a new import statement if
it is not already defined.

If IDENTIFIER is defined then the import statement is defined as
a \"from\" statement instead.

If the import statement already exists no action is taken; if it
does not, it is created. If IDENTIFIER is defined and MODULE
already declared, the existing \"from IMPORT\" clause is updated
with IDENTIFIER."
  (error "NYI"))

(defun python-mp-stringp (pt)
  "Return t if PT is in a Python string.

Uses `parse-partial-sexp' to infer the context of point."
  ;; Are there cases where point could be in a string but without a
  ;; string symbol?
    (eq 'string (syntax-ppss-context (syntax-ppss pt))))

(defun python-mp-commentp (pt)
  "Returns t if PT is in a Python comment."
  (eq 'comment (syntax-ppss-context (syntax-ppss pt))))

(defun python-mp-extract-dwim ()
  "Extracts the expression, string or sexp at point and returns
it."
  ;; if point is in a string we want to extract all of it.
  (cond
   ((python-mp-stringp (point))
    (save-excursion
      (python-beginning-of-string)
      (delete-and-extract-region (point) (save-excursion (forward-sexp) (point)))))
   ((python-mp-commentp (point))
    (error "Cannot use Extract Expression in a comment"))
   (t
    (let ((bounds (bounds-of-thing-at-point 'sexp)))
      (if bounds
          (delete-and-extract-region (car bounds) (cdr bounds))
        (error "Cannot find a valid expression"))))))

(defun python-mp-extract-to (name place)
  "Extracts the expression, string, or sexp using
`python-mp-extract-dwim' to a variable NAME in PLACE.

PLACE must be one of the following valid symbols: `class' for the
class point is in; `def' to add it to the top of the def
statement point is in; `block' to add it to the top of the block
point is in."
  (save-excursion
    (unless name (error "Must have a valid name"))
    (setq oldpt (point))
    (catch 'done
      (while
          (progn
            ;; blocks use `python-beginning-of-block'
            (if (eq place 'block)
                (python-beginning-of-block)
              (python-beginning-of-defun))
            ;; keep going back to the previous def or class until we
            ;; encounter the statement we're looking for. If we're
            ;; looking for a block we simply proceed without
            ;; checking at all.
            (when (or (looking-at
                       (if (eq place 'class)
                           python-mp-class-regexp
                         python-mp-def-regexp))
                      (eq place 'block))
              ;; we must do this here as we're manipulating the
              ;; buffer later on and that will throw off `oldpt'.
              (setq full-expr
                    (concat name " = "
                            (save-excursion
                              (goto-char oldpt)
                              (python-mp-extract-dwim))))
              ;; FIXME: this assumes that `end-of-line' is "end of
              ;; block"; it might not be?
              (end-of-line)
              (newline-and-indent)
              ;; stick the new expression into the buffer...
              (insert full-expr)
              ;; ... and signal the catch statement that we're done.
              (throw 'done nil))
            ;; loop condition here means we stop looking if we hit
            ;; 0'th indentation level as that's as far back as we
            ;; can go without jumping to earlier, unrelated,
            ;; statements.
            (> (python-mp-indentation-at-point (point)) 0)))
      (message "No statement found."))
    (message (concat (symbol-name place) " --> " (python-initial-text))))
  (insert name))

(defun python-mp-extract-to-block (name)
  "Extracts the expression, string, or sexp at point to the
nearest `block' statement."
  (interactive "sName: ")
  (python-mp-extract-to name 'block))

(defun python-mp-extract-to-class (name)
  "Extracts the expression, string, or sexp at point to the
nearest `class' statement."
  (interactive "sName: ")
  (python-mp-extract-to name 'class))

(defun python-mp-extract-to-def (name)
  "Extracts the expression, string, or sexp at point to the
nearest `def' statement."
  (interactive "sName: ")
  (python-mp-extract-to name 'def))

(defun python-mp-send-arg (arg)
  "Constructs a FUNC(ARG) request to an inferior-python process and
sends it without interrupting user input"
  (let ((proc (get-buffer-process (current-buffer))))
    (if proc
        (progn
          ;; construct a query for `python-shell' of the form 'func(arg)'.
          ;; FIXME: better way?
          (comint-send-string proc arg)
          ;; count the number of lines left between `point' and
          ;; `window-end'. If it this number is 0 or 1 we're at the
          ;; last line and thus we shouldn't move the point to the
          ;; very end, as the user invoked the command on
          ;; a line they're still editing.
          (if (> (count-lines (point) (window-end)) 1)
              (goto-char (point-max))))
      (error "No process found"))))

(defun python-mp-add-parameter (param)
  "Appends a parameter to the Python function point belongs to.

If there are no functions then an error is raised.
If called from within a class -- but outside a method body -- an error is raised."
  (interactive "sParameter: ")
  (save-excursion
    (save-restriction
      (widen)
      ;; point is now at the beginning of defun.
      ;;
      ;; FIXME: This would obviously fail in `python-mode.el'. There's
      ;; no function by that name there as far as i know.
      (python-beginning-of-defun)
      ;; only defs can have parameters.
      (if (not (looking-at python-mp-def-regexp))
          (error "Can only add parameters to functions"))

      ;; find the opening parenthesis for the parameter list then move
      ;; forward one s-expression so we end up at the end. We *could*
      ;; search for ':' instead then go back but if someone were to
      ;; use that character as a default parameter value that would
      ;; fail.
      (search-forward "(")
      (backward-char)
      (forward-sexp)
      ;; if we have an empty parameter list we simply go back one char
      ;; to enter the expression
      (if (looking-back (rx "(" (0+ (any space)) ")"))
          (progn
            ;; jump back to the beginning of the expression then
            ;; forward one char - that should put us right inside the
            ;; expression
            (goto-char (match-beginning 0))
            (forward-char))
        ;; ... but if the expression isn't empty we simply move
        ;; backwards one character.
        (backward-char)
        (if (re-search-backward (rx (not (any "(" space))))
            (progn
              (forward-char)
              (insert ", "))
          (error "Cannot find a valid parameter field")))
      (insert param)
      ;; Show the modified line in the minibuffer.
      ;;
      ;; FIXME: if it's somehow spread out over multiple lines we'll
      ;; only get the line we added our own parameter to. I guess
      ;; that's OK?
      (message (python-initial-text)))))


;;; HACK: Fix broken python-proc in python.el
;; (defun python-proc ()
;;   "Return the current Python process.
;; See variable `python-buffer'.  Starts a new process if necessary."
;;   ;; Fixme: Maybe should look for another active process if there
;;   ;; isn't one for `python-buffer'.
;;   (unless (comint-check-proc python-buffer)
;;     (run-python nil t))
;;   ;; update ALL python-mode processes to use this one IF AND ONLY IF
;;   ;; they have a dead process buffer in their `python-buffer' variable
;;   (let ((py-proc (get-buffer-process
;;                   (if (derived-mode-p 'inferior-python-mode)
;;                       (current-buffer)
;;                     python-buffer))))
;;     (dolist (buf (buffer-list))
;;       (with-current-buffer buf
;;         (if (and (derived-mode-p 'python-mode) (not (buffer-live-p python-buffer)))
;;             (setq python-buffer (get-buffer-process py-proc)))))
;;     py-proc))

; Sends the contents of the buffer then switches to the python buffer.
(defun python-mp-send-and-switch ()
  "Sends the current buffer to Python but only after moving point
to the end of the buffer. After that it switches back to the
inferior python buffer."
  (interactive)
  (let ((currshell python-buffer)
	(currbuffer (buffer-name)))
    ;; switch to python so we can jump to end-of-buffer.
    (with-selected-window (selected-window)
      (python-switch-to-python currshell)
      (goto-char (point-max)))
    ;; we're back in the python buffer. send the output then switch
    ;; back to the shell again
    (python-send-buffer)
    (python-switch-to-python currshell)
    (message (concat "Sent python buffer " currbuffer  " at " (current-time-string)))))

(defun python-mp-smart-quote ()
  "Inserts another pair of quotes -- either single or double -- if point is on a quote symbol."
  (error "NYI")
  )

(defun python-mp-indentation-at-point (pt)
  "Determines the indentation at PT. This approach does not use
\\[python-mode]'s internal data structures as we're not
interested in the *possible* indentation levels but merely what
PT currently has.

If the line contains nothing but whitespace (as determined by the
syntax table) then and `indent-count' is 0 we recursively
backtrack one line at a time until that condition is no longer
satisfied."
  (save-excursion
    (unless (bobp)
      (goto-char pt)
      (beginning-of-line)
      (setq indent-count
            (- (progn
                 ;; `line-end-position' seems like the best way to
                 ;; limit the search; but is it enough?
                 (skip-syntax-forward " " (line-end-position))
                 (point))
               (point-at-bol)))
      ;; FIXME: can `indent-count' ever be less than 0?
      ;;
      ;; make sure we're eolp also or we run into the nasty situation
      ;; where `indent-count' is 0 and yet the line contains code.
      (if (and (= indent-count 0) (eolp))
          (progn
            (forward-line -1)
            (python-mp-indentation-at-point (point)))
        indent-count))))


;;FIXME: this is a bit hacky...
(defun python-mp-reindent ()
  "Reindents the active region if \\[transient-mark-mode] is on."
  (interactive)
  (if (region-active-p)
      ;; shift the region by 0 lines which means it'll stay where it
      ;; is but reindent.
      (progn
        (python-mp-shift-region 0 'smart)
        (deactivate-mark))
    ;; there is a special place in hell reserved for people who alter
    ;; `this-command' and `last-command'.
    (let ((this-command 'indent-for-tab-command)
          (last-command 'indent-for-tab-command))
      ;; default to the usual python-mode indentation function.
      (indent-for-tab-command))))

(defun python-mp-shift-region (arg subr)
  "Shifts the active region ARG times up (backward if ARG is
negative) and reindents the code according to the indentation
depth in that block if SUBR is `'smart'. "
  ;;; Code loosely based off code snarfed from Andreas Politz on
  ;;; `gnu.emacs.help'.
  (progn
    ;; if there's no region active we should act on the entire line
    ;; instead. That avoids the uncomfortable situation where mark is
    ;; *somewhere* in the buffer and shifting the region would move
    ;; the region from point to mark.
    (unless (region-active-p)
      (set-mark
       (save-excursion
         (forward-line 0)
         (point)))
      (end-of-line)
      ;; we must have this or we won't include the newline.
      (forward-char)
      (activate-mark))
    (if (> (point) (mark))
        (exchange-point-and-mark))
    (let ((column (current-column))
          (text (delete-and-extract-region (point) (mark))))
      ;; FIXME: this sorta breaks the undo ring if you shift a
      ;; region and then immediately `undo'. This needs to be
      ;; fixed. The workaround is to do something to add to the
      ;; undo-ring (like movement) then it'll work fine.
      (unwind-protect
          (progn
            (buffer-disable-undo)
            (forward-line arg)
            (move-to-column column t)
            (set-mark (point))
            (insert text))
        (buffer-enable-undo))
      ;; without this point would be at the end of the region
      (exchange-point-and-mark)
      (if (eq subr 'smart)
          (progn
            (indent-rigidly (point) (mark)
                            ;; the inner-most block indentation level
                            ;; is what we're after. Subtract the
                            ;; current indentation at point (the
                            ;; top-most line in the region) from it
                            ;; to get the amount we need to rigidly
                            ;; indent by.
                            (- (caar (last (python-indentation-levels)))
                               (python-mp-indentation-at-point (point))))))
      (setq deactivate-mark nil))))

(defun python-mp-force-indent (amount)
  "Forcibly indents/unindents a region by AMOUNT"
  (interactive "*p")
  (save-excursion
    (when (> (point) (mark))
     (exchange-point-and-mark))
   (indent-rigidly (point) (mark) amount)
   (setq deactivate-mark nil)))

(defun python-mp-indent-left (arg)
  "Indents the region to the left ARG times

By default, ARG is 1, so the indentation amount is `python-indent'"
  (interactive "*p")
  (python-mp-force-indent (* (- 0 python-indent) arg)))

(defun python-mp-indent-right (arg)
  "Indents the region to the right ARG times

By default, ARG is 1, so the indentation amount is `python-indent'"
  (interactive "*p")
  (python-mp-force-indent (* python-indent arg)))

(defun python-mp-shift-region-down (arg)
  "If the region is active and \\[transient-mark-mode] is enabled
the region will be shifted down ARG times and reindented."
  (interactive "*p")
  (python-mp-shift-region arg 'smart))

(defun python-mp-shift-region-up (arg)
  "If the region is active and \\[transient-mark-mode] is enabled
the region will be shifted up ARG times and reindented."
  (interactive "*p")
  (python-mp-shift-region (- arg) 'smart))

;;; inferior-python-mode

;; `python-mode' enhancements.
(font-lock-add-keywords 'inferior-python-mode
  `(
    ;; rudimentary string handler routine. I could snarf the one used
    ;; by `python-mode' but I don't think it would make much
    ;; sense. This one has the added advantage of making it very
    ;; difficult for `font-lock-string-face' to "bleed" if a closing
    ;; quote character is missing.
    (,(rx (group (any "\"'"))
         (*? nonl)
         (backref 1)) . font-lock-string-face)))


(provide 'python-extras)

;;; python-extras.el ends here
