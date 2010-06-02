;;; python-extras.el --- Extras for python-mode

;; Filename: python-extras.el
;; Description: Extras for python-mode
;; Author: Mickey Petersen <mickey@fyeah.org>
;; Maintainer: Mickey Petersen <mickey@fyeah.org>
;; Copyright (C) 2010, Mickey Petersen, all rights reserved.
;; Created: 2010-05-22 21:21:04
;; Version: 0.1
;; Last-Updated: 2010-05-22 21:21:04
;;           By: Mickey Petersen
;; Keywords: python utility refactor extras
;; Compatibility: GNU Emacs 23.1.94.1
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
;;
;;; How to use
;;
;; By default several commands are bound to various 'C-c' keybinds.
;;
;; In \\[python-mode]:
;;
;; C-c C-p - Calls `python-mp-add-parameter' which will prompt you for
;; a parameter to add to the function point is currently in. If you
;; are not in a function body an error is raised.
;;
;; <RET> - Now rebound to `newline-and-indent' -- as it should be.
;;
;;
;; In inferior python mode:
;; 
;; C-c C-d - Sends a dir(EXPR) command where EXPR is the expression at
;; point. It will preserve your current input.
;;
;; C-d C-h - Sends a help(EXPR command where EXPR is the expressio nat
;; point. It will also preserve your current input.
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

;;; Require

(require 'rx)
(require 'comint)
(require 'python)
(require 'thingatpt)

;;; Code:


;;; Keymaps
(define-key python-mode-map (kbd "C-c C-s") 'python-mp-send-and-switch)
(define-key python-mode-map (kbd "C-c C-p") 'python-mp-add-parameter)
(define-key python-mode-map (kbd "C-m") 'newline-and-indent)

(define-key inferior-python-mode-map (kbd "C-c C-h") 'python-mp-send-help)
(define-key inferior-python-mode-map (kbd "C-c C-d") 'python-mp-send-dir)

(defun python-mp-send-help ()
  "Sends a help(EXPR) command when called from an inferior python
buffer, where EXPR is an expression at Point."
  (interactive (if (eq major-mode 'inferior-python-mode)
                   (python-mp-compile-comint-query "help" (python-mp-get-word-at-pt)))))

(defun python-mp-send-dir ()
  "Sends a dir(EXPR) command when called from an inferior python
buffer, where EXPR is an expression at Point."
  (interactive (if (eq major-mode 'inferior-python-mode)
                   (python-mp-compile-comint-query "dir" (python-mp-get-word-at-pt)))))

(defun python-mp-get-word-at-pt ()
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
           arg
           (stringp func)
           (stringp arg))
      (python-mp-send-func func arg)
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

(defun python-mp-extract-to-constant ()
  "Not Yet Implemented. Extracts the expression at point as a constant locally to the
class (if any) or globally otherwise."
  (error "NYI"))

(defun python-mp-send-func (func arg)
  "Constructs a FUNC(ARG) request to an inferior-python process and
sends it without interrupting user input"
  (let ((proc (get-buffer-process (current-buffer))))
      (if proc
          (progn
            ;; construct a query for `python-shell' of the form 'func(arg)'.
            ;; FIXME: better way?
            (comint-send-string proc (concat func "(" arg ")" "\n"))
            ;; count the number of lines left between `point' and
            ;; `window-end'. If it this number is 0 or 1 we're at the
            ;; last line and thus we shouldn't move the point to the
            ;; very end, as the user invoked the command on
            ;; a line they're still editing.
            )
        (if (> (count-lines (point) (window-end)) 1)
            (goto-char (point-max)))
        (error "No process found"))))

(defconst python-mp-def-regexp (rx bol (0+ (any space)) "def")
  "Regular expression `python-mp-add-parameter' uses to match a
function definition")

(defun python-mp-add-parameter (param)
  "Appends a parameter to the Python function point belongs to.

If there are no functions then an error is raised.
If called from within a class -- but outside a method body -- an error is raised."
  (interactive "sParameter: ")
  (save-excursion
    (save-restriction
      (widen)
      ;; point is now at the beginning of defun. FIXME: This would
      ;; obviously fail in `python-mode.el'. There's no function by
      ;; that name there as far as i know.
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

; Sends the contents of the buffer then switches to the python buffer.
(defun python-mp-send-and-switch ()
  "Sends the current buffer to Python but only after moving point to the end of the buffer. After that it switches to the Python buffer. "
  (interactive)
  (let ((currshell python-buffer)
	(currbuffer (buffer-name)))
    ;; switch to python so we can jump to end-of-buffer.
    (with-selected-window (selected-window)
      (python-switch-to-python currshell)
      (end-of-buffer))
    ;; we're back in the python buffer. send the output then switch
    ;; back to the shell again
    (python-send-buffer)
    (python-switch-to-python currshell)
    (message (concat "Sent python buffer " currbuffer  " at " (current-time-string)))))

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