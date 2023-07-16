;;; jpt-apl-mode.el --- APL minor mode -*- lexical-binding: t; no-byte-compile: nil  ;;-

;; Copyright © 2023- Pandora Norge
;; Author: John Thingstad
;; Created: 2 mar. 2023
;; Maintainer: jpthing@online.no

;; This file is not part of GNU Emacs

;;; License:
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see
;; <http://www.gnu.org/licenses/>

;;; Commentary:

;; This code gives a APL interface to Emacs for april - a common lisp embedded APL language
;; See: https://github.com/phantomics/april
;; The interface inspired by https://tryapl.org as I was not that happy with the gnu-apl-mode
;; interface. The unicode characters of APL are entered with two key strokes and a tab - called a cord.
;; They are a mnemonic where the keys when combined look simular to what the unicode chacter looks like.
;; I find that makes them more intuitive and easy to remember.
;;
;; Examples:
;;   aa<tab> → ⍺,  xx<tab> → ×, 0~<tab> → ⍬, <><tab> → ◊
;;
;; There is a optional header which displays the APL characters. When you click them they are entered in the code
;; at the cursor position. When you hover over them a popup is displayed. I contains: the operator, the monadic and
;; dyadic meaning and the key cord. You can enter the key cord from the keyboard if you don't want to mouse-click the
;; header character.
;;

;;; Technical issues:

;; go here

;;; Code:

;; Data used for entering APL unicode chacters and making the toolbar.

(require 'anaphora)

(defvar-local jpt-apl-exclude-plist
    (list
     :ascii  '(?+ ?- ?! ?\? ?= ?~ ?| ?/ ?\\ ?, ?. ?@ ?&)
     :dyalog '(?≡ ?≢ ?⍞ ?⌶ ?&)
     :gnu    '(?⍹ ?⍶)))

(make-variable-buffer-local
 (defvar jpt-apl-data
   '((?← "assign" ?< ?-) (?→ "branch" ?- ?>)
     (?+ "conjugate/plus") (?- "negate/minus")
     (?× "direction/times" ?x ?x) (?÷ "reciprocal/divide" ?: ?-)
     (?⍟ "ln/log" ?* ?o) (?! "factorial/binominal") (?\? "roll/deal")
     (?⌹ "matrix inverse/matrix divide" ?\[ ?-) (?○ "pi times/circular" ?O ?O)
     (?| "magnitude/reidue") (?⌈ "ceiling/maximum" ?7 ?7) (?⌊ "floor/minimum" ?l ?l) (?⊥ "decode" ?| ?_)
     (?⊤ "encode" ?T ?T) (?⊣ "same/left" ?- ?|) (?⊢ "same/right" ?| ?-)
     (?= "equal") (?≠ "unique mask/not equal" ?= ?/) (?≤ "less or equal to" ?< ?=) (?≥ "greater or equal to" ?> ?=)
     (?≡ "depht/match" ?= ?=) (?≢"tally/not match" ?7 ?=)
     (?∨ "Greatest common divisor/or" ?v ?v) (?∧ "lowest common multiple/and" ?^ ?^) (?⍱ "nand" ?v ?~) (?⍲ "nor" ?^ ?~)
     (?↑ "mix/take" ?^ ?|) (?↓ "split/drop" ?v ?|) (?⊂ "enclose/partial enclose" ?\( ?\() (?⊃ "first/pick" ?\) ?\))
     (?⊆ "nest/partition" ?\( ?_) (?⌷ "index" ?| ?\]) (?⍋ "grade up" ?A ?|) (?⍒ "grade down" ?V ?|)
     (?⍳ "indices/indices of" ?i ?i) (?⍸ "where/where index" ?i ?_) (?∊ "enlist/member of" ?e ?e) (?⍷ "find" ?e ?_)
     (?∪ "unique/union" ?u ?u) (?∩ "intersection" ?n ?n) (?~ "not/without")
     (?/ "replicate/reduce") (?\\ "expand/scan")
     (?⌿ "replicate first/reduce first" ?/ ?-) (?⍀ "expand first/scan first" ?\\ ?-)
     (?, "ravel/catinate/laminate") (?⍪ "table/catenate first" ?, ?-) (?⍴ "shape/reshape" ?p ?p) (?⌽ "reverse/rotate" ?O ?|)
     (?⊖ "reverse first/rotate first" ?O ?-) (?⍉ "transpose/reorder axis" ?O ?\\)
     (?¨ "each" ?: ?:) (?⍨ "constant/self/swap" ?~ ?:) (?⍣ "repeat" ?* ?:) (?. "outer product (.∘)/inner product")
     (?∘ ".∘ outer product & ∘ curry/compose" ?o ?o) (?⍤ "rank/atop" ?o ?:) (?ö "over" ?O ?:)
     (?@ "at") (?⍞ "Character input/output" ?\[ ?\')
     (?⎕ "systen name " ?\[ ?\]) (?⍠ "variant" ?\[ ?:) (?⌸ "index key/key" ?\[ ?=) (?⌺ "stencil" ?\[ ?<) (?⌶ "I-beam" ?T ?_)
     (?◊ "statement seperator" ?< ?>) (?⍝ "comment" ?o ?n)
     (?⍵ "right argument/right operand" ?w ?w) (?⍹ "values as OP" ?w ?_) (?⍺ "left argument/left operand" ?a ?a) (?⍶ "values as OP" ?a ?_)
     (?∇ "recursion" ?v ?-) (?& "spawn")
     (?¯ "negative" ?- ?-) (?⍬ "empty numeric vector" ?0 ?~))))

;;
;; Custom
;;

(defgroup jpt-apl-header nil
  "APL: toolbar support."
  :group 'jpt-apl
  :link '(emacs-commentary-link :tab "Commentary" "jpt-apl-mode.el")
  :prefix "jpt-apl-")

(defcustom jpt-apl-use-header t
  "Non-nil means APL should display the header"
  :type 'boolean)

(defcustom jpt-apl-exclude '(:ascii :dyalog)
  "Determines which apl characters are displayed in the header.
The default is to exclude ASCII characters and those that are used
by Dyalog but not april.
Nil allows all APL characters. Options: :ascii :dyalog :gnu"
  :type 'list)

(defcustom jpt-apl-mode-global nil
  "non-nil means the apl header and key cords are available in all Emacs buffers.
Othewise they are available only only in lisp buffers and at the repl
For beginners it is probaly better to leave it at nil"
  :type 'boolean)

(defvar jpt-apl-mode-hook nil)

;;
;; header
;;

(defvar-local jpt-apl-cord-map nil
  "Stores alist of (keycord . code) maps")

(defvar-local jpt-apl-used-data
    "jtp-apl-data, but filtered to remove entries spesified by jpt-apl-exclude.")

(defun get-code (data) (car data))

(defun get-help-string (data)
  (if (= (length data) 4)
      (cl-destructuring-bind (code help-string key1 key2) data
	(let ((help-list (string-split help-string "/")))
	  (format "%c\n%s\n%s\n%c %c %s"
		  code
		  (car help-list)
		  (if (null (cadr help-list)) "" (cadr help-list))
		  key1 key2 "tab")))
    (cl-destructuring-bind (code help-string) data
      (let ((help-list (string-split help-string "/")))
	(format "%c\n%s\n%s\n"
		code
		(car help-list)
		(if (null (cadr help-list)) "" (cadr help-list)))))))

(defun buttonize-entry (entry)
  (let ((button
	 (buttonize (char-to-string (get-code entry))
		    (lambda (data) (insert-char data))
		    (get-code entry)
		    (get-help-string entry))))
    (add-face-text-property 0 (length button) '(:underline nil) nil button)
    button))

(defun jpt-apl-make-header ()
  "Returns a string of text-buttons. Each button is a APL character.
For each button:
Left mouse click inserts character at the cursor in the file.
Mouseover shows the key explanation in the form:
- APL character
- monadic meaning
- dyadic meaning
- keystroke
Keystroke are a triplet of characters two ASCII and a tab that generate the
APL character. The kestroke can always be entered instead of clicking the key."
  (let (button-list)
    (dolist (entry jpt-apl-used-data)
      (push " " button-list)
      (push (buttonize-entry entry) button-list))
    (nreverse button-list)))

(defun jpt-apl-insert-header ()
  (setq-local header-line-format (jpt-apl-make-header)))

(defun jpt-apl-remove-header ()
  (setq header-line-format nil))

(defun jpt-apl-maybe-header ()
  "When jpt-apl-use-header is set display header.
Toggle it on/off in sync with the enable/disable cycle of the mode"
      (if (jpt-apl-use-header)
	  (progn
	    (setq-local jpt-apl-insert-header t)
	    (jpt-apl-insert-header))
	(setq-local jpt-apl-use-header nil)
	(jpt-apl-remove-header)))
;;
;; Convert jpt-apl-data to keymap
;; Returns:
;; (let ((map (make-keymap)))
;;   (define-key map (kbd "x x <tab>") (lambda () (insert-char ?×)))
;;   ...)
;;

(defun jpt-apl-make-cord-map (data)
  (dolist (entry data)
    (when (= (length entry) 4)
      (cl-destructuring-bind (u _ c1 c2) entry
	(let ((cord (concat (list c1) (list c2))))
	  (push `(,cord . ,u) jpt-apl-cord-map))))))

(defun jpt-apl-match-keycord ()
  (interactive)
  ;; read last two chars before cursor into cord
  (let ((cord
	 (save-excursion
	   (let* ((c2 (char-before))
		  (c1 (char-before (backward-char))))
	     (concat (list c1) (list c2))))))
    ;; if cord is in map
    (awhen (cdr (assoc cord jpt-apl-cord-map))
      ;; erase last two chars and replace them with code
      (delete-char -2)
      (insert-char it))))

(defun jpt-apl-merge-entries (exclude-filter char-plist)
  (let (result)
    (while exclude-filter
      (setq result (cl-union (plist-get char-plist (car exclude-filter)) result))
      (setq exclude-filter (cdr exclude-filter)))
    result
    ))

(defun jpt-apl-filter-data (data exclude-filter exclude-plist)
  (aif (jpt-apl-merge-entries exclude-filter exclude-plist)
      (cl-remove-if (lambda (elt) (member (car elt) it)) data)
    it))

(defun jpt-apl-init ()
  (setq-local jpt-apl-used-data (jpt-apl-filter-data jpt-apl-data jpt-apl-exclude jpt-apl-exclude-plist))
  (unless jpt-apl-cord-map
    (jpt-apl-make-cord-map jpt-apl-used-data))
  (jpt-apl-maybe-header))

;;;###autoload
(define-minor-mode jpt-apl-mode
  "Minor mode for entering apl characters"
  :global nil
  :init-value nil
  :lighter " APL"
  :keymap (let ((map (make-sparse-keymap)))
	    (define-key map (kbd "<tab>") #'jpt-apl-match-keycord)
	    map))

(add-hook 'jpt-apl-mode-hook #'jpt-apl-init)


(provide 'jpt-apl-mode)
