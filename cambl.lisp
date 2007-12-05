;; -*- mode: lisp -*-

;; cambl.lisp - This is the Commoditized AMounts and BaLances library.

;;;_* Copyright (c) 2003-2007, John Wiegley.  All rights reserved.

;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are
;; met:
;;
;; - Redistributions of source code must retain the above copyright
;;   notice, this list of conditions and the following disclaimer.
;;
;; - Redistributions in binary form must reproduce the above copyright
;;   notice, this list of conditions and the following disclaimer in the
;;   documentation and/or other materials provided with the distribution.
;;
;; - Neither the name of New Artisans LLC nor the names of its
;;   contributors may be used to endorse or promote products derived from
;;   this software without specific prior written permission.
;;
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;; A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;; OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;; DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

;;;_* Commentary

;; This library aims to provide convenient access to commoditized math.  That
;; is, math involving numbers with units.  However, unlike scientific units,
;; this library does not allow the use of "compound" units.  If you divide 1kg
;; by 1m, you do not get "1 kg/m", but an error.  This is because the intended
;; use is for situations that do not allow compounded units, such as financial
;; transactions, and the algorithms have been simplified accordingly.  It also
;; allows contextual information to be tracked during commodity calculations
;; -- the time of conversion from one type to another, the rated value at the
;; time of conversion.

;;;_ * Usage: Conventions

;; 

;;;_ * Usage: Amounts

;; There are just a few main entry points to the CAMBL library for dealing
;; with amounts (which is mainly how you'll use it).  Here is a quick list,
;; following by a description in the context of a REPL session.  Note that
;; where the name contains value, it will work for integers, amounts and
;; balances.  If it contains amount or balance, it only operates on entities
;; of that type.
;;
;;   amount[*]          ; create an amount from a string
;;   exact-amount       ; create an amount from a string which overrides
;;                      ; its commodity's display precision; this feature
;;                      ; "sticks" through any math operations
;;   parse-amount[*]    ; parse an amount from a string (alias for `amount')
;;   read-amount[*]     ; read an amount from a stream
;;   read-exact-amount  ; read an exact amount from a stream
;;   format-value       ; format a value to a string
;;   print-value        ; print a value to a stream
;;
;;   add[*]             ; perform math using values; the values are
;;   subtract[*]        ; changed as necessary to preserve information
;;   multiply[*]        ; (adding two amounts may result in a balance)
;;   divide[*]          ; the * versions change the first argument.
;;
;;   value-zerop        ; would the value display as zero?
;;   value-zerop*       ; is the value truly zero?
;;
;;   value-minusp       ; would the amount display as a negative amount?
;;   value-minusp*      ; is the amount truly negative?
;;   value-plusp        ; would it display as an amount greater than zero?
;;   value-plusp*       ; is it truly greater than zero?
;;
;;   value=, value/=    ; compare two values
;;   value<, value<=    ; compare values (not meaningful for all values,
;;   value>, value>=    ; such as balances)
;;
;;   value-equal        ; compare two values for exact match
;;   value-equalp       ; compare two values only after rounding to what
;;                      ; would be shown to the user (approximate match)
;;                      ; -- this is the same as value=
;;   value-not-equal    ; compare if two values for not an exact match
;;   value-not-equalp   ; compare two values after commodity rounding
;;
;;   value-lessp        ; same as value<
;;   value-lessp*       ; compare if a < b exactly, with full precision
;;   value-lesseqp      ; same as value<=
;;   value-lesseqp*     ; exact version of value<=
;;   value-greaterp     ; same as value>
;;   value-greaterp*    ; exact version of value>
;;   value-greatereqp   ; same as value>=
;;   value-greatereqp*  ; exact version of value>=
;;
;;   amount-precision   ; return the internal precision of an amount
;;   display-precision  ; return the "display" precision for an amount
;;                      ; or a commodity
;;
;;   *european-style*   ; set this to T if you want to see 1.000,00 style
;;                      ; numbers printed instead of 1,000.00 (US) style.
;;                      ; This also influences how amounts are parsed.

;;;_ * Example Session

;; Interacting with CAMBL begin with creating an amount.  This is done most
;; easily from a string, but it can also be read from a stream:
;;
;;   (cambl:amount "$100.00") =>
;;     #<CAMBL:AMOUNT "$100.00" :KEEP-PRECISION-P NIL>
;;
;;   (with-input-from-string (in "$100.00"))
;;      (cambl:read-amount in)) =>
;;     #<CAMBL:AMOUNT "$100.00" :KEEP-PRECISION-P NIL>
;;
;; When you parse an amount using one of these two functions, CAMBL creates a
;; COMMODITY class for you, whose symbol name is "$".  This class remembers
;; details about how you used the commodity, such as the input precision and
;; the format of the commodity symbol.  Some of these details can be inspected
;; by looking at the amount's commodity directly:
;;
;;   (cambl:amount-commodity (cambl:amount "$100.00")) =>
;;     #<CAMBL::COMMODITY #S(CAMBL::COMMODITY-SYMBOL
;;                           :NAME $
;;                           :NEEDS-QUOTING-P NIL
;;                           :PREFIXED-P T
;;                           :CONNECTED-P T)
;;         :THOUSAND-MARKS-P NIL :DISPLAY-PRECISION 2>
;;
;; Here you can see that the commodity for $100.00 is $, and it knows that the
;; commodity should be prefixed to the amount, and that it gets connected to
;; the amount.  This commodity was used without any "thousand marks" (i.e.,
;; $1000.00 vs $1,000.00), and it has a maximum display precision of TWO
;; observed so far.  If we print sach an amount, we'll see the same style as
;; was input:
;;
;;   (cambl:format-value (cambl:amount "$100.00")) => "$100.00"
;;   (cambl:print-value (cambl:amount "$100.00"))  => NIL
;;     $100.00
;;
;; CAMBL observed how you used the "$" commodity, and now reports back all
;; dollar figures after the same fashion.  Even though there are no cents in
;; the amounts above, CAMBL will still record a full two digits of precision
;; (this becomes important during division, to guard against fractional losses
;; during repeated rounding).
;;
;;   (cambl:amount-precision (cambl:amount "$100.00")) => 2
;;
;; CAMBL remembers the greatest precision it has seen thus far, but never
;; records a lesser precision.  So if you parse $100.00 and then $100, both
;; values will be printed as $100.00.
;;
;; There are three functions for creating amounts, but they have some subtle
;; differences where precision is concerned.  They are: `amount', `amount*',
;; and `exact-amount'.  Here are the differences:
;;
;;   (cambl:amount "$100.00") =>
;;     #<CAMBL:AMOUNT "$100.00" :KEEP-PRECISION-P NIL>
;;
;;       a. amount has an internal precision of 2
;;       b. commodity $ has a display precision of 2 (if no other
;;          amount using a higher precision was observed so far)
;;       c. when printing, amount uses the commodity's precision
;;  
;;         (cambl:format-value *)                      => "$100.00"
;;         (cambl:format-value ** :full-precision-p t) => "$100.00"
;;
;;   (cambl:amount* "$100.0000") =>
;;     #<CAMBL:AMOUNT "$100.0000" :KEEP-PRECISION-P NIL>
;;
;;       a. amount has an internal precision of 4
;;       b. commodity $ still has a display precision of 2 (from above)
;;       c. when printing, amount uses the commodity's precision
;;  
;;         (cambl:format-value *)                      => "$100.00"
;;         (cambl:format-value ** :full-precision-p t) => "$100.0000"
;;
;;   (cambl:exact-amount "$100.0000") =>
;;     #<CAMBL:AMOUNT "$100.0000" :KEEP-PRECISION-P T>
;;
;;       a. amount has an internal precision of 4
;;       b. commodity $ still has a display precision of 2 (from above)
;;       c. when printing, amount uses its internal precision
;;  
;;         (cambl:format-value *)                      => "$100.0000"
;;         (cambl:format-value ** :full-precision-p t) => "$100.0000"
;;
;; There are similar variants for the stream reading functions:
;;
;;   read-amount
;;   read-amount*
;;   read-exact-amount
;;
;; NOTE: The KEEP-PRECISION-P property of an amount carries through any math
;; operations involving that amount, so that the final result is ealways
;; displayed using its own internal percision.
;;
;; The point of all this is that amounts are displayed as the user expects
;; them to be, but internally never lose information.  In fact, if you divide
;; two high internal precision amounts together, you'll get a new amount with
;; a very high internal precision, but which still displays as expected:
;;
;;   (setf *tmp* (cambl:divide  (cambl:amount "$100.00")
;;                              (cambl:amount "50000000")))
;;
;;   (cambl:format-value *tmp* :full-precision-p t) =>
;;     "$0.000002000000000"
;;   (cambl:format-value *tmp*) => "$0.00"
;;
;; You'll notice here that the amount displayed is not $0.00000200000000002.
;; This is because CAMBL does not try to capture every digit resulting from a
;; division; rather, it keeps six more digits of precision than is strictly
;; necessary so that even after millions of calculations, not a penny is lost.
;; If you find this is not enough slack for your calculations, you can set
;; CAMBL:*EXTRA-PRECISION* to a higher or lower value.

;;;_ * Usage: Commodities

;; CAMBL offers several methods for accessing the commodity information
;; relating to amounts:
;;
;;   amount-commodity          ; the COMMODITY referenced by an amount
;;   display-precision         ; display precision of an AMOUNT or COMMODITY
;;   commodity-qualified-name  ; the name used print a COMMODITY
;;   commodity-annotated-p     ; does the commodity have an annotation?

;;;_* Package

(declaim (optimize (debug 3) (safety 3) (speed 1) (space 0)))

(defpackage :cambl
  (:use :cl :red-black :local-time :periods)
  (:export *european-style*
	   pushend

	   value
	   valuep
	   amount
	   amount-p
	   amount*
	   amount-sans-commodity
	   parse-amount
	   parse-amount*
	   exact-amount
	   read-amount
	   read-amount*
	   read-exact-amount
	   float-to-amount
	   integer-to-amount
	   amount-quantity

	   balance
	   balance-p
	   get-amounts-map
	   amount-in-balance

	   copy-amount
	   copy-balance
	   copy-from-balance
	   copy-value

	   value-zerop
	   value-zerop*
	   value-minusp
	   value-minusp*
	   value-plusp
	   value-plusp*

	   value-truth
	   value-truth*

	   compare
	   compare*
	   sign
	   sign*

	   value-equal
	   value-equalp
	   value-not-equal
	   value-not-equalp
	   value=
	   value/=

	   value-lessp
	   value-lessp*
	   value-lesseqp
	   value-lesseqp*
	   value<
	   value<=

	   value-greaterp
	   value-greaterp*
	   value-greatereqp
	   value-greatereqp*
	   value>
	   value>=

	   value-abs
	   value-round
	   value-round*

	   negate*
	   negate
	   add
	   add*
	   subtract
	   subtract*
	   multiply
	   multiply*
	   divide
	   divide*

	   optimize-value
	   amount-of-value
	   print-value
	   format-value
	   quantity-string

	   exchange-commodity
	   purchase-commodity
	   sell-commodity

	   amount-commodity
	   balance-first-amount
	   balance-commodities
	   balance-commodity-count
	   commodity-name
	   amount-precision
	   amount-keep-precision-p
	   display-precision

	   amount-error

	   market-value

	   commodity-qualified-name
	   commodity-thousand-marks-p
	   commodity-equal
	   commodity-equalp
	   commodity-lessp

	   commodity-annotated-p
	   make-commodity-annotation
	   commodity-annotation
	   commodity-annotation-equal
	   annotation-price
	   annotation-date
	   annotation-tag
	   annotate-commodity
	   annotated-commodity
	   strip-annotations

	   commodity-pool
	   *default-commodity-pool*
	   make-commodity-pool
	   reset-commodity-pool
	   find-commodity
	   find-annotated-commodity

	   commodity-error))

(in-package :cambl)

;;;_* Types

(deftype value ()
  '(or integer amount balance))

(declaim (inline valuep))
(defun valuep (object)
  (typep object 'value))

;;;_ - COMMODITY-SYMBOL

(defstruct commodity-symbol
  (name "" :type string)
  (needs-quoting-p nil :type boolean)
  (prefixed-p nil :type boolean)
  (connected-p nil :type boolean))

;;;_ - BASIC-COMMODITY

(defstruct (basic-commodity (:conc-name get-))
  symbol
  (description nil :type (or string null))
  (comment nil :type (or string null))
  (thousand-marks-p nil :type boolean)
  (no-market-price-p nil :type boolean)
  (builtin-p nil :type boolean)
  (display-precision 0 :type fixnum)
  (price-history nil)
  (last-lookup nil :type (or fixed-time null)))

(defstruct pricing-entry
  moment
  price)				; (:type amount)

;;;_ - COMMODITY-POOL

(defstruct commodity-pool
  (by-name-map (make-hash-table :test 'equal) :type hash-table)
  (default-commodity nil))

(defparameter *default-commodity-pool* (make-commodity-pool))

;;;_ + COMMODITY

;; Commodities are references to basic commodities, which store the common
;; details.  This is so the commodities USD and $ can both refer to the same
;; underlying kind.

(defclass commodity ()
  ((basic-commodity :accessor get-basic-commodity :initarg :basic-commodity
		    :type basic-commodity)
   (commodity-pool :accessor get-commodity-pool :initarg :commodity-pool
		   :type commodity-pool)
   (qualified-name :accessor commodity-qualified-name :initarg :qualified-name
		   :type (or string null))
   ;; This is set automatically by initialize-instance whenever an
   ;; annotated-commodity is created.
   (annotated-p :accessor get-annotated-p :initform nil :type boolean)))

(defmethod print-object ((commodity commodity) stream)
  (print-unreadable-object (commodity stream :type t)
    (let ((base (get-basic-commodity commodity)))
      (princ (get-symbol base) stream)
      (format stream "~%    :THOUSAND-MARKS-P ~S :DISPLAY-PRECISION ~D"
	      (get-thousand-marks-p base) (get-display-precision base)))))

;;;_ + COMMODITY-ANNOTATION

(defstruct (commodity-annotation
	     (:conc-name annotation-))
  (price nil) ;; (:type (or amount null))
  (date nil :type (or fixed-time null))
  (tag nil :type (or string null)))

;;;_ + ANNOTATED-COMMODITY

(defclass annotated-commodity (commodity)
  ((referent-commodity :accessor get-referent-commodity
		       :initarg :referent-commodity :type commodity)
   (annotation :accessor get-annotation :initarg :annotation
	       ;; :type commodity-annotation
	       )))

(defmethod print-object ((annotated-commodity annotated-commodity) stream)
  (print-unreadable-object (annotated-commodity stream :type t)
    (let ((base (get-basic-commodity
		 (get-referent-commodity annotated-commodity))))
      (princ (get-symbol base) stream)
      (format stream "~%    :THOUSAND-MARKS-P ~S :DISPLAY-PRECISION ~D"
	      (get-thousand-marks-p base) (get-display-precision base)))))

(defmethod initialize-instance :after
    ((annotated-commodity annotated-commodity) &key)
  (setf (get-annotated-p annotated-commodity) t))

;;;_ + AMOUNT

;; Amounts are bignums with a specific attached commodity.  [TODO: Also, when
;; math is performed with them, they retain knowledge of the origins of their
;; value].

;; The following three members determine whether lot details are maintained
;; when working with commoditized values.  The default is false for all three.
;;
;; Let's say a user adds two values of the following form:
;;   10 AAPL + 10 AAPL {$20}
;;
;; This expression adds ten shares of Apple stock with another ten shares that
;; were purchased for $20 a share.  If `keep_price' is false, the result of
;; this expression will be an amount equal to 20 AAPL.  If `keep_price' is
;; true, the expression yields an exception for adding amounts with different
;; commodities.  In that case, a balance_t object must be used to store the
;; combined sum.

(defstruct (amount (:print-function print-amount))
  (commodity nil :type (or commodity null))
  (quantity 0 :type integer)
  (precision 0 :type fixnum)
  (keep-precision-p nil :type boolean))

;;;_ + BALANCE

(defclass balance ()
  ((amounts-map :accessor get-amounts-map :initform nil)))

(defmethod print-object ((balance balance) stream)
  (print-unreadable-object (balance stream :type t)
    (mapc #'(lambda (entry)
	      (terpri stream)
	      (princ "     " stream)
	      (princ (cdr entry) stream))
	  (get-amounts-map balance))))

;;;_* Generics

;;;_ + Public generics

;; - If the argument says item, this means:
;;   amount, commodity, annotated-commodity, null
;; - If the argument says any-item, this means:
;;   amount, balance, commodity, annotated-commodity, null
;; - If it says value, this means:
;;   amount, balance

(defgeneric copy-value (value))

(defgeneric value-zerop (value))
(defgeneric value-zerop* (value))	; is it *really* zerop?
(defgeneric value-minusp (value))
(defgeneric value-minusp* (value))	; is it *really* minusp?
(defgeneric value-plusp (value))
(defgeneric value-plusp* (value))	; is it *really* plusp?

(defgeneric compare (left right))
(defgeneric compare* (left right))
(defgeneric value-equal (left right))
(defgeneric value-equalp (left right))
(defgeneric value-not-equal (left right))
(defgeneric value-not-equalp (left right))
(defgeneric value= (left right))
(defgeneric value/= (left right))

(defgeneric value-abs (value))

(defgeneric negate* (value))
(defgeneric negate (value))
(defgeneric add (value-a value-b))
(defgeneric add* (value-a value-b))
(defgeneric subtract (value-a value-b))
(defgeneric subtract* (value-a value-b))
(defgeneric multiply (value-a value-b))
(defgeneric multiply* (value-a value-b))
(defgeneric divide (value-a value-b))
(defgeneric divide* (value-a value-b))

(defgeneric optimize-value (value))
(defgeneric amount-of-value (value))

(defgeneric print-value (value &key output-stream omit-commodity-p
			       full-precision-p width latter-width line-feed-string))
(defgeneric format-value (value &key omit-commodity-p full-precision-p
				width latter-width line-feed-string))

(defgeneric amount-in-balance (balance commodity))

(defgeneric commodity-equal (item-a item-b))
(defgeneric commodity-equalp (item-a item-b)) ; ignores annotation

(defgeneric commodity-name (item))
(defgeneric display-precision (item))

(defgeneric market-value (any-item &optional fixed-time))

(defgeneric commodity-annotated-p (item))
(defgeneric commodity-annotation (item))
(defgeneric commodity-annotation-equal (left-item right-item))
(defgeneric annotate-commodity (item annotation))
(defgeneric strip-annotations (any-item &key keep-price keep-date keep-tag))

;;;_ - Private generics

(defgeneric commodity-base (commodity))
(defgeneric commodity-symbol (commodity))
(defgeneric commodity-precision (commodity))
(defgeneric commodity-thousand-marks-p (commodity))
(defgeneric commodity-description (item))
(defgeneric commodity-no-market-price-p (commodity))
(defgeneric commodity-builtin-p (commodity))

(defgeneric commodity-annotation-empty-p (item))

;;;_* Object printing functions

(defun print-amount (amount stream depth)
  (declare (ignore depth))
  (print-unreadable-object (amount stream :type t)
    (format stream "~S :KEEP-PRECISION-P ~S"
	    (format-value amount :full-precision-p t)
	    (amount-keep-precision-p amount))))

;;;_* Constants

(defparameter *invalid-symbol-chars*
  #(#|        0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f |#
    #| 00 |# nil nil nil nil nil nil nil nil nil  t   t  nil nil  t  nil nil
    #| 10 |# nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil
    #| 20 |#  t   t   t  nil nil nil  t  nil  t   t   t   t   t   t   t   t 
    #| 30 |#  t   t   t   t   t   t   t   t   t   t   t   t   t   t   t   t 
    #| 40 |#  t  nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil
    #| 50 |# nil nil nil nil nil nil nil nil nil nil nil  t  nil  t   t  nil
    #| 60 |# nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil
    #| 70 |# nil nil nil nil nil nil nil nil nil nil nil  t  nil  t   t  nil
    #| 80 |# nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil
    #| 90 |# nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil
    #| a0 |# nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil
    #| b0 |# nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil
    #| c0 |# nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil
    #| d0 |# nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil
    #| e0 |# nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil
    #| f0 |# nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil)
  "The invalid commodity symbol characters are:

  Space Tab Newline Return
  0-9 . , ; - + * / ^ ? : & | ! = \"
  < > { } [ ] ( ) @")

;;;_* Global Variables

(defvar *european-style* nil
  "If set to T, amounts will be printed as 1.000,00.
The default is US style, which is 1,000.00.  Note that thousand markers are
only used if the commodity's own THOUSAND-MARKS-P accessor returns T.")

(defvar *extra-precision* 6
  "Specify the amount of \"extra\" to be added during amount division.")

(defvar *keep-annotation-prices* t)
(defvar *keep-annotation-dates* t)
(defvar *keep-annotation-tags* t)

;;;_* Functions

;;;_ * BASIC-COMMODITY

(defun apply-base-commodity* (function commodity &rest args)
  (declare (type function function))
  (if (typep commodity 'annotated-commodity)
      (setf commodity (get-referent-commodity commodity)))
  (apply function (get-basic-commodity commodity) args))

(defun apply-base-commodity (function amount-or-commodity &rest args)
  (declare (type function function))
  (if (typep amount-or-commodity 'amount)
      (setf amount-or-commodity (amount-commodity amount-or-commodity)))
  (if (typep amount-or-commodity 'annotated-commodity)
      (setf amount-or-commodity (get-referent-commodity amount-or-commodity)))
  (apply function (get-basic-commodity amount-or-commodity) args))

;;;_ * AMOUNT and BALANCE

;;;_  + Error class

(define-condition amount-error (error) 
  ((description :reader error-description :initarg :msg))
  (:report (lambda (condition stream)
	     (format stream "~S" (error-description condition)))))

;;;_  + Create AMOUNT objects from strings

(defun amount (data &key (pool *default-commodity-pool*))
  (etypecase data
    (string
     (with-input-from-string (in data)
       (read-amount in :observe-properties-p t :pool pool)))
    (integer
     (integer-to-amount data))))

(defun amount* (data &key (pool *default-commodity-pool*))
  (etypecase data
    (string
     (with-input-from-string (in data)
       (read-amount in :observe-properties-p nil :pool pool)))
    (integer
     (integer-to-amount data))))

(declaim (inline parse-amount))
(defun parse-amount (&rest args)
  (apply #'amount args))

(declaim (inline parse-amount*))
(defun parse-amount* (&rest args)
  (apply #'amount args))

(defun exact-amount (text &key (pool *default-commodity-pool*))
  (let ((amount
	 (amount* text :pool pool)))
    (setf (amount-keep-precision-p amount) t)
    amount))

;;;_  + Read AMOUNT objects from streams

(defun read-amount-quantity (in)
  (declare (type stream in))
  (with-output-to-string (buf)
    (let (last-special)
      (loop
	 for c = (read-char in nil) while c do
	 (if (digit-char-p c)
	     (progn
	       (when last-special
		 (write-char last-special buf)
		 (setf last-special nil))
	       (write-char c buf))
	     (if (and (null last-special)
		      (or (char= c #\-)
			  (char= c #\.)
			  (char= c #\,)))
		 (setf last-special c)
		 (progn
		   (unread-char c in)
		   (return)))))
      (if last-special
	  (unread-char last-special in)))))

(defun peek-char-in-line (in &optional skip-whitespace)
  (declare (type stream in))
  (loop
     for c = (peek-char nil in nil)
     while (and c (char/= c #\Newline)) do
     (if (and skip-whitespace
	      (or (char= #\Space c)
		  (char= #\Tab c)))
	 (read-char in)
	 (return c))))

(defun read-amount (in &key (observe-properties-p t)
		    (pool *default-commodity-pool*))
  "Parse an AMOUNT from the input IN, which may be a stream or string.

  If :OBSERVE-PROPERTIES-P is T (the default), any display details noticed in
this amount will be set as defaults for displaying this kind of commodity in
the future.

  If :POOL is set, any commodities created by this routine (a maximum possible
of two, if an annotated price is given with a second commodity) will be
associated with the given commodity pool.

  The possible syntax for an amount is:
  
  [-]NUM[ ]SYM [ANNOTATION]
  SYM[ ][-]NUM [ANNOTATION]"
  (declare (type stream in))

  (let (symbol quantity details negative-p
	       (connected-p t) (prefixed-p t) thousand-marks-p
	       amount)

    (when (char= #\- (peek-char-in-line in t))
      (setf negative-p t)
      (read-char in))

    (if (digit-char-p (peek-char-in-line in t))
	(progn
	  (setf quantity (read-amount-quantity in))
	  (assert quantity)

	  (let ((c (peek-char-in-line in)))
	    (if (and (characterp c)
		     (char= #\Space c))
		(setf connected-p nil))
	    (let ((n (peek-char-in-line in t)))
	      (when (and (characterp n)
			 (not (char= #\Newline n)))
		(setf symbol (read-commodity-symbol in))
		(if symbol
		    (setf prefixed-p nil))))))
	(progn
	  (setf symbol (read-commodity-symbol in))
	  (if (char= #\Space (peek-char nil in))
	      (setf connected-p nil))
	  (let ((n (peek-char-in-line in t)))
	    (if (and (characterp n)
		     (not (char= #\Newline n)))
		(setf quantity (read-amount-quantity in))
		(error 'amount-error :msg
		       "No quantity specified for amount")))))

    (let ((c (peek-char-in-line in t)))
      (if (and (characterp c)
	       (or (char= c #\{)
		   (char= c #\[)
		   (char= c #\()))
	  (setf details (read-commodity-annotation in))))

    ;; Now that we have the full commodity symbol, create the commodity object
    ;; it refers to
    (multiple-value-bind (commodity newly-created-p)
	(if (and symbol
		 (not (cl:zerop (length (commodity-symbol-name symbol)))))
	    (if details
		(find-annotated-commodity symbol details :pool pool
					  :create-if-not-exists-p t)
		(find-commodity symbol :pool pool :create-if-not-exists-p t))
	    (values nil nil))

      ;; Determine the precision of the amount, based on the usage of
      ;; comma or period.
      (setf amount (make-amount :commodity commodity))

      (let ((last-comma (position #\, quantity :from-end t))
	    (last-period (position #\. quantity :from-end t)))
	(if (or (and *european-style* last-period)
		(and (not *european-style*) last-comma))
	    (setf thousand-marks-p t))
	(cond ((and last-comma last-period)
	       (setf (amount-precision amount)
		     (- (length quantity) (if (> last-comma last-period)
					      last-comma last-period) 1)))
	      ((and last-comma *european-style*)
	       (setf (amount-precision amount)
		     (- (length quantity) last-comma 1)))
	      ((and last-period (not *european-style*))
	       (setf (amount-precision amount)
		     (- (length quantity) last-period 1)))
	      (t
	       (setf (amount-precision amount) 0))))

      (setf (amount-quantity amount)
	    (parse-integer (delete-if #'(lambda (c)
					  (or (char= #\. c)
					      (char= #\, c))) quantity)))

      (if commodity
	  (when (or newly-created-p observe-properties-p)
	    ;; Observe the commodity usage details we noticed while parsing
	    (setf (commodity-symbol-prefixed-p
		   (commodity-symbol commodity)) prefixed-p)
	    (setf (commodity-symbol-connected-p
		   (commodity-symbol commodity)) connected-p)
	    (if thousand-marks-p
		(setf (get-thousand-marks-p (commodity-base commodity))
		      thousand-marks-p))

	    (let ((precision (amount-precision amount)))
	      (if (> precision (display-precision commodity))
		  (setf (get-display-precision (commodity-base commodity))
			precision))))
	  ;; If the amount had no commodity at all, always preserve full
	  ;; precision, as if the user had used `exact-amount'.
	  (setf (amount-keep-precision-p amount) t)))

    (if negative-p
	(negate* amount))

    (the amount amount)))

(defun read-amount* (in &key (pool *default-commodity-pool*))
  (read-amount in :observe-properties-p nil :pool pool))

(defun read-exact-amount (text &key (pool *default-commodity-pool*))
  (let ((amount
	 (read-amount* text :pool pool)))
    (setf (amount-keep-precision-p amount) t)
    amount))

;;;_  + Convert other values to and from AMOUNT

(declaim (inline integer-to-amount))

(defun integer-to-amount (value)
  (declare (type (or integer fixnum) value))
  (the amount
    (make-amount :quantity value :precision 0)))

(defun amount-to-integer (amount &key (dont-check-p t))
  (declare (type amount amount))
  (declare (type boolean dont-check-p))
  (multiple-value-bind (quotient remainder)
      (truncate (amount-quantity amount)
		(expt 10 (amount-precision amount)))
    (if (and (not dont-check-p) remainder)
	(error 'amount-error :msg
	       "Conversion of amount to integer loses precision"))
    quotient))

;;;_  + Create BALANCE objects from other amounts

(defun balance (&rest amounts)
  (let ((tmp (make-instance 'balance)))
    (dolist (amount amounts)
      (add* tmp amount))
    tmp))

(declaim (inline balance-p))
(defun balance-p (object)
  (typep object 'balance))

;;;_  + Copiers

(defmethod copy-value ((amount integer))
  amount)

(defmethod copy-value ((amount amount))
  (copy-amount amount))

(declaim (inline copy-balance))
(defun copy-balance (balance)
  (declare (type balance balance))
  (let ((tmp (make-instance 'balance)))
    (mapc #'(lambda (entry)
	      (add* tmp (copy-amount (cdr entry))))
	  (get-amounts-map balance))
    tmp))

(declaim (inline copy-from-balance))
(defun copy-from-balance (balance)
  (declare (type balance balance))
  (let ((count (balance-commodity-count balance)))
    (if (= count 0)
	0
	(if (= count 1)
	    (copy-amount (cdr (nth 0 (get-amounts-map balance))))
	    (copy-balance balance)))))

(defmethod copy-value ((balance balance))
  (copy-balance balance))

;;;_  + Unary truth tests

(declaim (inline value-maybe-round))
(defun value-maybe-round (amount)
  (declare (type amount amount))
  (if (amount-keep-precision-p amount)
      amount
      (value-round amount)))

(defmethod value-zerop ((integer integer))
  (cl:zerop integer))
(defmethod value-zerop ((amount amount))
  (cl:zerop (amount-quantity (value-maybe-round amount))))
(defmethod value-zerop ((balance balance))
  (block outer
    (mapc #'(lambda (entry)
	      (unless (value-zerop (cdr entry))
		(return-from outer)))
	  (get-amounts-map balance))
    t))

(defmethod value-zerop* ((integer integer))
  (cl:zerop integer))
(defmethod value-zerop* ((amount amount))
  (cl:zerop (amount-quantity amount)))
(defmethod value-zerop* ((balance balance))
  (block outer
    (mapc #'(lambda (entry)
	      (unless (value-zerop* (cdr entry))
		(return-from outer)))
	  (get-amounts-map balance))
    t))

(defmethod value-minusp ((integer integer))
  (cl:minusp integer))
(defmethod value-minusp ((amount amount))
  (cl:minusp (amount-quantity (value-maybe-round amount))))
(defmethod value-minusp ((balance balance))
  (block outer
    (mapc #'(lambda (entry)
	      (unless (value-minusp (cdr entry))
		(return-from outer)))
	  (get-amounts-map balance))
    t))

(defmethod value-minusp* ((integer integer))
  (cl:minusp integer))
(defmethod value-minusp* ((amount amount))
  (cl:minusp (amount-quantity amount)))
(defmethod value-minusp* ((balance balance))
  (block outer
    (mapc #'(lambda (entry)
	      (unless (value-minusp* (cdr entry))
		(return-from outer)))
	  (get-amounts-map balance))
    t))

(defmethod value-plusp ((integer integer))
  (cl:plusp integer))
(defmethod value-plusp ((amount amount))
  (cl:plusp (amount-quantity (value-maybe-round amount))))
(defmethod value-plusp ((balance balance))
  (block outer
    (mapc #'(lambda (entry)
	      (unless (value-plusp (cdr entry))
		(return-from outer)))
	  (get-amounts-map balance))
    t))

(defmethod value-plusp* ((integer integer))
  (cl:plusp integer))
(defmethod value-plusp* ((amount amount))
  (cl:plusp (amount-quantity amount)))
(defmethod value-plusp* ((balance balance))
  (block outer
    (mapc #'(lambda (entry)
	      (unless (value-plusp* (cdr entry))
		(return-from outer)))
	  (get-amounts-map balance))
    t))

(defun value-basic-truth (result zerop-test-func)
  (etypecase result
    (amount
     (not (funcall zerop-test-func result)))
    (balance
     (not (funcall zerop-test-func result)))
    (integer
     (not (zerop result)))
    (string
     (> (length result) 0))
    (fixed-time
     ;; jww (2007-11-11): NYI
     nil)
    (boolean
     result)))

(declaim (inline value-truth value-truth*))
(defun value-truth (result)
  (value-basic-truth result #'value-zerop))
(defun value-truth* (result)
  (value-basic-truth result #'value-zerop*))

;;;_  + BALANCE commodity details

(declaim (inline balance-commodities
		 balance-first-amount
		 balance-commodity-count))

(defun balance-commodities (balance)
  (mapcar #'car (get-amounts-map balance)))

(defun balance-first-amount (balance)
  (assert (cl:plusp (balance-commodity-count balance)))
  (cdar (get-amounts-map balance)))

(defun balance-commodity-count (balance)
  (length (get-amounts-map balance)))

;;;_  + AMOUNT comparison (return sort order of value)

(defun verify-amounts (left right capitalized-gerund)
  (declare (type amount left))
  (declare (type amount right))
  (let ((left-commodity (amount-commodity left))
	(right-commodity (amount-commodity right)))
    (unless (or (null left-commodity)
		(null right-commodity)
		(commodity-equal left-commodity right-commodity))
      (error 'amount-error :msg
	     (format nil "~A amounts with different commodities: ~A != ~A"
		     capitalized-gerund
		     (commodity-name left)
		     (commodity-name right))))))

(defmethod compare ((left integer) (right integer))
  (- left right))
(defmethod compare ((left amount) (right integer))
  (let ((tmp (integer-to-amount right))
	(left-rounded (value-maybe-round left)))
    (compare* left-rounded tmp)))
(defmethod compare ((left integer) (right amount))
  (let ((tmp (integer-to-amount left))
	(right-rounded (value-maybe-round right)))
    (compare* tmp right-rounded)))
(defmethod compare ((left amount) (right amount))
  (verify-amounts left right "Comparing")
  (let ((left-rounded (value-maybe-round left))
	(right-rounded (value-maybe-round right)))
    (compare* left-rounded right-rounded)))
(defmethod compare ((left balance) (right integer))
  (compare (amount-of-value left) right))
(defmethod compare ((left balance) (right amount))
  (compare (amount-of-value left) right))
(defmethod compare ((left integer) (right balance))
  (compare left (amount-of-value right)))
(defmethod compare ((left amount) (right balance))
  (compare left (amount-of-value right)))
(defmethod compare ((left balance) (right balance))
  (compare (amount-of-value left) (amount-of-value right)))

(defmethod compare* ((left integer) (right integer))
  (- left right))
(defmethod compare* ((left amount) (right integer))
  (compare* left (integer-to-amount right)))
(defmethod compare* ((left integer) (right amount))
  (compare* (integer-to-amount left) right))

(declaim (inline resize-quantity))
(defun resize-quantity (amount precision)
  (declare (optimize (speed 3) (safety 0)))
  (locally #+sbcl (declare (sb-ext:muffle-conditions
			    sb-ext:compiler-note))
      (* (amount-quantity amount)
	 (expt 10 (the (unsigned-byte 8)
		    (- (the fixnum precision)
		       (amount-precision amount)))))))

(defmethod compare* ((left amount) (right amount))
  (verify-amounts left right "Exactly comparing")
  (the integer
    (cond ((= (amount-precision left) (amount-precision right))
	   (- (amount-quantity left) (amount-quantity right)))
	  ((< (amount-precision left) (amount-precision right))
	   (- (resize-quantity left (amount-precision right))
	      (amount-quantity right)))
	  (t
	   (- (amount-quantity left)
	      (resize-quantity right (amount-precision left)))))))

(defmethod compare* ((left balance) (right integer))
  (compare* (amount-of-value left) right))
(defmethod compare* ((left balance) (right amount))
  (compare* (amount-of-value left) right))
(defmethod compare* ((left integer) (right balance))
  (compare* left (amount-of-value right)))
(defmethod compare* ((left amount) (right balance))
  (compare* left (amount-of-value right)))
(defmethod compare* ((left balance) (right balance))
  (compare* (amount-of-value left) (amount-of-value right)))

(defun sign (amount)
  "Return -1, 0 or 1 depending on the sign of AMOUNT."
  (etypecase amount
    (integer (sign* amount))
    (amount (sign* (value-maybe-round amount)))))

(defun sign* (amount)
  "Return -1, 0 or 1 depending on the sign of AMOUNT."
  (etypecase amount
    (integer
     (if (cl:minusp amount)
	 -1
	 (if (cl:plusp amount)
	     1
	     0)))
    (amount
     (let ((quantity (amount-quantity amount)))
       (if (cl:minusp quantity)
	   -1
	   (if (cl:plusp quantity)
	       1
	       0))))))

;;;_  + Equality tests

(defun amount-balance-equal (left right test-func)
  "Compare with the amount LEFT equals the balance RIGHT."
  (let ((amounts-map (get-amounts-map right)))
    (if (value-zerop* left)
	(or (null amounts-map)
	    (cl:zerop (length amounts-map)))
	(if (and amounts-map
		 (= 1 (length amounts-map)))
	    (let ((amount-value (cdr (assoc (amount-commodity left)
					    amounts-map))))
	      (if amount-value
		  (funcall test-func amount-value left)))))))

(defun balance-equal (left right test-func)
  (let ((left-amounts-map (get-amounts-map left))
	(right-amounts-map (get-amounts-map right)))
    (the boolean
      (when (= (length left-amounts-map)
	       (length right-amounts-map))
	(block nil
	  (mapc
	   #'(lambda (entry)
	       (let ((right-value
		      (cdr (assoc (car entry) right-amounts-map))))
		 (unless right-value
		   (return nil))
		 (unless (funcall test-func (cdr entry) right-value)
		   (return nil))))
	   left-amounts-map)
	  t)))))

(defmethod value-equal ((left integer) (right integer))
  (equal left right))
(defmethod value-equal ((left amount) (right integer))
  (cl:zerop (compare* left right)))
(defmethod value-equal ((left integer) (right amount))
  (cl:zerop (compare* left right)))
(defmethod value-equal ((left amount) (right amount))
  (cl:zerop (compare* left right)))
(defmethod value-equal ((left balance) (right integer))
  (amount-balance-equal right left #'value-equal))
(defmethod value-equal ((left balance) (right amount))
  (amount-balance-equal right left #'value-equal))
(defmethod value-equal ((left integer) (right balance))
  (amount-balance-equal left right #'value-equal))
(defmethod value-equal ((left amount) (right balance))
  (amount-balance-equal left right #'value-equal))
(defmethod value-equal ((left balance) (right balance))
  (balance-equal left right #'value-equal))

(defmethod value-equalp ((left integer) (right integer))
  (equalp left right))
(defmethod value-equalp ((left amount) (right integer))
  (cl:zerop (compare left right)))
(defmethod value-equalp ((left integer) (right amount))
  (cl:zerop (compare left right)))
(defmethod value-equalp ((left amount) (right amount))
  (cl:zerop (compare left right)))
(defmethod value-equalp ((left balance) (right integer))
  (amount-balance-equal right left #'value-equalp))
(defmethod value-equalp ((left balance) (right amount))
  (amount-balance-equal right left #'value-equalp))
(defmethod value-equalp ((left integer) (right balance))
  (amount-balance-equal left right #'value-equalp))
(defmethod value-equalp ((left amount) (right balance))
  (amount-balance-equal left right #'value-equalp))
(defmethod value-equalp ((left balance) (right balance))
  (balance-equal left right #'value-equalp))

(defmethod value-not-equal ((left integer) (right integer))
  (not (equal left right)))
(defmethod value-not-equal ((left amount) (right integer))
  (not (cl:zerop (compare* left right))))
(defmethod value-not-equal ((left integer) (right amount))
  (not (cl:zerop (compare* left right))))
(defmethod value-not-equal ((left amount) (right amount))
  (not (cl:zerop (compare* left right))))
(defmethod value-not-equal ((left balance) (right integer))
  (not (amount-balance-equal right left #'value-equal)))
(defmethod value-not-equal ((left balance) (right amount))
  (not (amount-balance-equal right left #'value-equal)))
(defmethod value-not-equal ((left integer) (right balance))
  (not (amount-balance-equal left right #'value-equal)))
(defmethod value-not-equal ((left amount) (right balance))
  (not (amount-balance-equal left right #'value-equal)))
(defmethod value-not-equal ((left balance) (right balance))
  (not (balance-equal left right #'value-equal)))

(defmethod value-not-equalp ((left integer) (right integer))
  (not (equalp left right)))
(defmethod value-not-equalp ((left amount) (right integer))
  (not (cl:zerop (compare left right))))
(defmethod value-not-equalp ((left integer) (right amount))
  (not (cl:zerop (compare left right))))
(defmethod value-not-equalp ((left amount) (right amount))
  (not (cl:zerop (compare left right))))
(defmethod value-not-equalp ((left balance) (right integer))
  (not (amount-balance-equal right left #'value-equalp)))
(defmethod value-not-equalp ((left balance) (right amount))
  (not (amount-balance-equal right left #'value-equalp)))
(defmethod value-not-equalp ((left integer) (right balance))
  (not (amount-balance-equal left right #'value-equalp)))
(defmethod value-not-equalp ((left amount) (right balance))
  (not (amount-balance-equal left right #'value-equalp)))
(defmethod value-not-equalp ((left balance) (right balance))
  (not (balance-equal left right #'value-equalp)))

(defmethod value= ((left integer) (right integer))
  (value-equalp left right))
(defmethod value= ((left amount) (right integer))
  (value-equalp left right))
(defmethod value= ((left integer) (right amount))
  (value-equalp left right))
(defmethod value= ((left amount) (right amount))
  (value-equalp left right))
(defmethod value= ((left balance) (right integer))
  (value-equalp left right))
(defmethod value= ((left balance) (right amount))
  (value-equalp left right))
(defmethod value= ((left integer) (right balance))
  (value-equalp left right))
(defmethod value= ((left amount) (right balance))
  (value-equalp left right))
(defmethod value= ((left balance) (right balance))
  (value-equalp left right))

(defmethod value/= ((left integer) (right integer))
  (not (value-equalp left right)))
(defmethod value/= ((left amount) (right integer))
  (not (value-equalp left right)))
(defmethod value/= ((left integer) (right amount))
  (not (value-equalp left right)))
(defmethod value/= ((left amount) (right amount))
  (not (value-equalp left right)))
(defmethod value/= ((left balance) (right integer))
  (not (value-equalp left right)))
(defmethod value/= ((left balance) (right amount))
  (not (value-equalp left right)))
(defmethod value/= ((left integer) (right balance))
  (not (value-equalp left right)))
(defmethod value/= ((left amount) (right balance))
  (not (value-equalp left right)))
(defmethod value/= ((left balance) (right balance))
  (not (value-equalp left right)))

;;;_  + Comparison tests

(declaim (inline value-lessp value-lessp*))
(defun value-lessp (left right)
  (cl:minusp (compare left right)))
(defun value-lessp* (left right)
  (cl:minusp (compare* left right)))

(declaim (inline value-lesseqp value-lesseqp*))
(defun value-lesseqp (left right)
  (<= (compare left right) 0))
(defun value-lesseqp* (left right)
  (<= (compare* left right) 0))

(declaim (inline value< value<=))
(defun value< (left right)
  (cl:minusp (compare left right)))
(defun value<= (left right)
  (<= (compare left right) 0))

(declaim (inline value-greaterp value-greaterp*))
(defun value-greaterp (left right)
  (cl:plusp (compare left right)))
(defun value-greaterp* (left right)
  (cl:plusp (compare* left right)))

(declaim (inline value-greatereqp value-greatereqp*))
(defun value-greatereqp (left right)
  (>= (compare left right) 0))
(defun value-greatereqp* (left right)
  (>= (compare* left right) 0))

(declaim (inline value> value>=))
(defun value> (left right)
  (cl:plusp (compare left right)))
(defun value>= (left right)
  (>= (compare left right) 0))

;;;_  + Unary math operators

(defmethod value-abs ((integer integer))
  (abs integer))

(defmethod value-abs ((amount amount))
  (assert amount)
  (if (cl:minusp (amount-quantity amount))
      (negate amount)
      amount))

(defmethod value-abs ((balance balance))
  (let ((value-balance (make-instance 'balance)))
    (mapc #'(lambda (entry)
	      (add* value-balance (value-abs (cdr entry))))
	  (get-amounts-map balance))
    value-balance))

(defun value-round (amount &optional precision)
  (value-round* (copy-amount amount) precision))

(defun value-round* (amount &optional precision)
  "Round the given AMOUNT to the stated internal PRECISION.

  If PRECISION is less than the current internal precision, data will be lost.
If it is greater, this operation has no effect."
  (etypecase amount
    (integer amount)
    (amount
     (unless precision
       (let ((commodity (amount-commodity amount)))
	 (setf precision (if commodity
			     (display-precision commodity)
			     0))))

     (let ((internal-precision (amount-precision amount)))
       (if (< precision internal-precision)
	   (setf (amount-quantity amount)
		 (round (amount-quantity amount)
			(expt 10 (- internal-precision precision)))
		 (amount-precision amount) precision)))
     amount)))

(defmethod negate ((integer integer))
  (- integer))

(defmethod negate ((amount amount))
  (negate* (copy-amount amount)))

(defmethod negate ((balance balance))
  (negate* (copy-balance balance)))

(defmethod negate* ((integer integer))
  (error "Cannot apply in-place negation to an integer"))

(defmethod negate* ((amount amount))
  (setf (amount-quantity amount)
	(- (amount-quantity amount)))
  amount)

(defmethod negate* ((balance balance))
  (mapc #'(lambda (entry)
	    (setf (cdr entry) (negate (cdr entry))))
	(get-amounts-map balance))
  balance)

;;;_  + Binary math operators

;;;_   : Addition

(defmethod add ((left integer) (right integer))
  (+ left right))
(defmethod add ((left amount) (right integer))
  (add* (copy-amount left) (integer-to-amount right)))
(defmethod add ((left integer) (right amount))
  (add* (integer-to-amount left) right))
(defmethod add ((left amount) (right amount))
  (add* (copy-amount left) right))
(defmethod add ((left balance) (right integer))
  (add* (copy-balance left) (integer-to-amount right)))
(defmethod add ((left balance) (right amount))
  (add* (copy-balance left) right))
(defmethod add ((left integer) (right balance))
  (add* (integer-to-amount left) right))
(defmethod add ((left amount) (right balance))
  (add* (copy-balance right) left))
(defmethod add ((left balance) (right balance))
  (add* (copy-balance left) right))

(defmethod add* ((left integer) (right integer))
  (error 'amount-error :msg "Integers do not support in-place addition"))
(defmethod add* ((left amount) (right integer))
  (add* left (integer-to-amount right)))
(defmethod add* ((left integer) (right amount))
  (error 'amount-error :msg "Integers do not support in-place addition"))
(defmethod add* ((left amount) (right amount))
  (the (or amount balance)
    (if (commodity-equal (amount-commodity left)
			 (amount-commodity right))
	(let ((left-quantity (amount-quantity left))
	      (right-quantity (amount-quantity right)))
	  (cond ((= (amount-precision left)
		    (amount-precision right))
		 (setf (amount-quantity left)
		       (+ left-quantity right-quantity)))
		((< (amount-precision left)
		    (amount-precision right))
		 (setf (amount-quantity left)
		       (+ (resize-quantity left (amount-precision right))
			  right-quantity)
		       (amount-precision left) (amount-precision right)))
		(t
		 (setf (amount-quantity left)
		       (+ left-quantity
			  (resize-quantity right (amount-precision left))))))
	  left)
	;; Commodities don't match, so create a balance by merging the two
	(let ((tmp (make-instance 'balance)))
	  (add* tmp left)
	  (add* tmp right)
	  tmp))))
(defmethod add* ((left balance) (right integer))
  (add* left (integer-to-amount right)))
(defmethod add* ((left balance) (right amount))
  (unless (value-zerop* right)
    (let ((current-amount (cdr (assoc (amount-commodity right)
				      (get-amounts-map left)))))
      (if current-amount
	  (add* current-amount right)	; modifies current-amount directly
	  (progn
	    (push (cons (amount-commodity right)
			(copy-amount right))
		  (get-amounts-map left))
	    ;; This is where the commodities need to get resorted, since we
	    ;; just pushed a new one on
	    (setf (get-amounts-map left)
		  (sort (get-amounts-map left)
			#'compare-amounts-visually))))))
  left)
(defmethod add* ((left integer) (right balance))
  (error 'amount-error :msg "Integers do not support in-place addition"))
(defmethod add* ((left amount) (right balance))
  (add right left))
(defmethod add* ((left balance) (right balance))
  (mapc #'(lambda (entry)
	    (add* left (cdr entry)))
	(get-amounts-map right))
  left)

;;;_   : Subtraction

(defmethod subtract ((left integer) (right integer))
  (- left right))
(defmethod subtract ((left amount) (right integer))
  (subtract* (copy-amount left) (integer-to-amount right)))
(defmethod subtract ((left integer) (right amount))
  (subtract* (integer-to-amount left) right))
(defmethod subtract ((left amount) (right amount))
  (subtract* (copy-amount left) right))
(defmethod subtract ((left balance) (right integer))
  (subtract* (copy-balance left) (integer-to-amount right)))
(defmethod subtract ((left balance) (right amount))
  (subtract* (copy-balance left) right))
(defmethod subtract ((left integer) (right balance))
  (error 'amount-error :msg "Cannot subtract a BALANCE from an INTEGER"))
(defmethod subtract ((left amount) (right balance))
  (error 'amount-error :msg "Cannot subtract a BALANCE from an AMOUNT"))
(defmethod subtract ((left balance) (right balance))
  (subtract* (copy-balance left) right))

(defmethod subtract* ((left integer) (right integer))
  (error 'amount-error :msg "Integers do not support in-place subtraction"))
(defmethod subtract* ((left amount) (right integer))
  (subtract* left (integer-to-amount right)))
(defmethod subtract* ((left integer) (right amount))
  (error 'amount-error :msg "Integers do not support in-place subtraction"))

(defmethod subtract* ((left amount) (right amount))
  (the (or amount balance)
    (if (commodity-equal (amount-commodity left)
			 (amount-commodity right))
	(let ((left-quantity (amount-quantity left))
	      (right-quantity (amount-quantity right)))
	  (cond ((= (amount-precision left)
		    (amount-precision right))
		 (setf (amount-quantity left)
		       (- left-quantity right-quantity)))
		((< (amount-precision left)
		    (amount-precision right))
		 (setf (amount-quantity left)
		       (- (resize-quantity left (amount-precision right))
			  right-quantity)
		       (amount-precision left) (amount-precision right)))
		(t
		 (setf (amount-quantity left)
		       (- left-quantity
			  (resize-quantity right (amount-precision left))))))
	  left)
	;; Commodities don't match, so create a balance by merging the two
	(let ((tmp (make-instance 'balance)))
	  (add* tmp left)
	  (add* tmp (negate right))
	  tmp))))

(defmethod subtract* ((left balance) (right integer))
  (subtract* left (integer-to-amount right)))

(defmethod subtract* ((left balance) (right amount))
  (unless (value-zerop* right)
    (let* ((amounts-map (get-amounts-map left))
	   (found-entry (assoc (amount-commodity right)
			       amounts-map))
	   (current-amount (cdr found-entry)))
      (if current-amount
	  (progn
	    ;; modify current-amount directly
	    (subtract* current-amount right)
	    ;; if the result is "true zero", drop this commodity from the
	    ;; balance altogether
	    (if (value-zerop* current-amount)
		(setf (get-amounts-map left)
		      (delete found-entry amounts-map)))
	    ;; if the amounts map is now only one element long, return just
	    ;; the amount, since this isn't a balance anymore
	    (if (cdr (get-amounts-map left))
		left
		current-amount))
	  (progn
	    (push (cons (amount-commodity right) (negate right))
		  (get-amounts-map left))
	    left)))))

(defmethod subtract* ((left integer) (right balance))
  (error 'amount-error :msg "Integers do not support in-place subtraction"))
(defmethod subtract* ((left amount) (right balance))
  (error 'amount-error :msg "Cannot subtract a BALANCE from an AMOUNT"))
(defmethod subtract* ((left balance) (right balance))
  (mapc #'(lambda (entry)
	    (subtract* left (cdr entry)))
	(get-amounts-map right))
  left)

;;;_   : Multiplication

(defmethod multiply ((left integer) (right integer))
  (* left right))
(defmethod multiply ((left amount) (right integer))
  (multiply* (copy-amount left) (integer-to-amount right)))
(defmethod multiply ((left integer) (right amount))
  (multiply* (integer-to-amount left) right))
(defmethod multiply ((left amount) (right amount))
  (multiply* (copy-amount left) right))
(defmethod multiply ((left balance) (right integer))
  (multiply* (copy-balance left) (integer-to-amount right)))
(defmethod multiply ((left balance) (right amount))
  (multiply* (copy-balance left) right))
(defmethod multiply ((left integer) (right balance))
  (error 'amount-error :msg "Cannot multiply an integer by a balance"))
(defmethod multiply ((left amount) (right balance))
  (error 'amount-error :msg "Cannot multiply an amount by a balance"))
(defmethod multiply ((left balance) (right balance))
  (error 'amount-error :msg "Cannot multiply a balance by another balance"))

(defmethod multiply* ((left integer) (right integer))
  (error 'amount-error :msg "Integers do not support in-place multiplication"))
(defmethod multiply* ((left amount) (right integer))
  (multiply* left (integer-to-amount right)))
(defmethod multiply* ((left integer) (right amount))
  (error 'amount-error :msg "Integers do not support in-place multiplication"))

(defun set-amount-commodity-and-round* (left right)
  (let ((commodity (amount-commodity left)))
    (unless commodity
      (setf (amount-commodity left)
	    (setf commodity (amount-commodity right))))

    ;; If this amount has a commodity, and we're not dealing with plain
    ;; numbers, or internal numbers (which keep full precision at all
    ;; times), then round the number to within the commodity's precision
    ;; plus six places.
    (when (and commodity (not (amount-keep-precision-p left)))
      (let ((commodity-precision (display-precision commodity)))
	(when (> (amount-precision left)
		 (+ *extra-precision* commodity-precision))
	  (setf (amount-quantity left)
		(cl:round (amount-quantity left)
			  (expt 10 (- (amount-precision left)
				      (+ *extra-precision* commodity-precision)))))
	  (setf (amount-precision left)
		(+ *extra-precision* commodity-precision))))))
  left)

(defmethod multiply* ((left amount) (right amount))
  (setf (amount-quantity left)
	(* (amount-quantity left)
	   (amount-quantity right)))
  (setf (amount-precision left)
	(+ (amount-precision left)
	   (amount-precision right)))
  (set-amount-commodity-and-round* left right))

(defmethod multiply* ((left balance) (right integer))
  (multiply* left (integer-to-amount right)))

(defmethod multiply* ((left balance) (right amount))
  (cond ((value-zerop* right)
	 right)
	((value-zerop* left)
	 left)
	(t
	 ;; Multiplying by an amount causes all the balance's amounts to be
	 ;; multiplied by the same factor.
	 (mapc #'(lambda (entry)
		   (multiply* (cdr entry) right))
	       (get-amounts-map left))
	 left)))

(defmethod multiply* ((left integer) (right balance))
  (error 'amount-error :msg "Integers do not support in-place multiplication"))
(defmethod multiply* ((left amount) (right balance))
  (error 'amount-error :msg "Cannot multiply an amount by a balance"))
(defmethod multiply* ((left balance) (right balance))
  (error 'amount-error :msg "Cannot multiply a balance by another balance"))

;;;_   : Division

(defmethod divide ((left integer) (right integer))
  (round left right))
(defmethod divide ((left amount) (right integer))
  (divide* (copy-amount left) (integer-to-amount right)))
(defmethod divide ((left integer) (right amount))
  (divide* (integer-to-amount left) right))
(defmethod divide ((left amount) (right amount))
  (divide* (copy-amount left) right))
(defmethod divide ((left balance) (right integer))
  (divide* (copy-balance left) (integer-to-amount right)))
(defmethod divide ((left balance) (right amount))
  (divide* (copy-balance left) right))
(defmethod divide ((left integer) (right balance))
  (error 'amount-error :msg "Cannot divide an integer by a balance"))
(defmethod divide ((left amount) (right balance))
  (error 'amount-error :msg "Cannot divide an amount by a balance"))
(defmethod divide ((left balance) (right balance))
  (error 'amount-error :msg "Cannot divide a balance by another balance"))

(defmethod divide* ((left integer) (right integer))
  (error 'amount-error :msg "Integers do not support in-place division"))
(defmethod divide* ((left amount) (right integer))
  (divide* left (integer-to-amount right)))
(defmethod divide* ((left integer) (right amount))
  (error 'amount-error :msg "Integers do not support in-place division"))

(defmethod divide* ((left amount) (right amount))
  ;; Increase the value's precision, to capture fractional parts after
  ;; the divide.  Round up in the last position.
  (if (value-zerop right)
      (error 'amount-error :msg
	     (format nil "Attempt to divide by zero: ~A / ~A"
		     (format-value left :full-precision-p t)
		     (format-value right :full-precision-p t))))

  (setf (amount-quantity left)
	(cl:round (* (amount-quantity left)
		     (expt 10 (+ (1+ *extra-precision*)
				 (* 2 (amount-precision right))
				 (amount-precision left))))
		  (amount-quantity right)))

  (setf (amount-precision left)
	(+ *extra-precision* (* 2 (amount-precision left))
	   (amount-precision right)))

  (setf (amount-quantity left)
	(cl:round (amount-quantity left)
		  (expt 10 (- (1+ (amount-precision left))
			      (amount-precision left)))))

  (set-amount-commodity-and-round* left right))

(defmethod divide* ((left balance) (right integer))
  (divide* left (integer-to-amount right)))

(defmethod divide* ((left balance) (right amount))
  (cond ((value-zerop* right)
	 (error 'amount-error :msg "Divide by zero"))
	((value-zerop* left)
	 left)
	(t
	 ;; Dividing by an amount causes all the balance's amounts to be
	 ;; divided by the same factor.
	 (mapc #'(lambda (entry)
		   (divide* (cdr entry) right))
	       (get-amounts-map left))
	 left)))

(defmethod divide* ((left integer) (right balance))
  (error 'amount-error :msg "Integers do not support in-place division"))
(defmethod divide* ((left amount) (right balance))
  (error 'amount-error :msg "Cannot divide an amount by a balance"))
(defmethod divide* ((left balance) (right balance))
  (error 'amount-error :msg "Cannot divide a balance by another balance"))

;;;_ * BALANCE specific

;;;_  + Optimize the given value, returning its cheapest equivalent

(defmethod optimize-value ((integer integer))
  integer)

(defmethod optimize-value ((amount amount))
  (if (value-zerop* amount)
      0
      amount))

(defmethod optimize-value ((balance balance))
  (block nil
    (let ((amounts-map (get-amounts-map balance)))
      (if (or (null amounts-map)
	      (cl:zerop (length amounts-map)))
	  0
	  (if (= 1 (length amounts-map))
	      (optimize-value (copy-amount (cdr (first amounts-map))))
	      balance)))))

(defmethod amount-of-value ((integer integer))
  (integer-to-amount integer))

(defmethod amount-of-value ((amount amount))
  amount)

(defmethod amount-of-value ((balance balance))
  (let ((amounts-map (get-amounts-map balance)))
    (if (or (null amounts-map)
	    (cl:zerop (length amounts-map)))
	(integer-to-amount 0)
	(if (= 1 (length amounts-map))
	    (cdr (first amounts-map))
	    (error "Cannot yield amount of a multi-commodity balance")))))

;;;_  + Print and format AMOUNT and BALANCE

(defmethod print-value ((amount amount) &key
			(output-stream *standard-output*)
			(omit-commodity-p nil)
			(full-precision-p nil)
			(width nil)
			latter-width
			line-feed-string)
  (declare (type stream output-stream))
  (declare (type boolean omit-commodity-p))
  (declare (type boolean full-precision-p))
  (declare (type (or fixnum null) width))
  (declare (ignore latter-width))
  (declare (ignore line-feed-string))

  (let* ((commodity (amount-commodity amount))
	 (omit-commodity-p (or omit-commodity-p (null commodity)))
	 (commodity-symbol (and (not omit-commodity-p) commodity
				(commodity-symbol commodity)))
	 (precision (amount-precision amount))
	 (quantity (amount-quantity amount))
	 (display-precision
	  (the fixnum
	    (if (or (null commodity)
		    full-precision-p
		    (amount-keep-precision-p amount))
		(amount-precision amount)
		(if (get-annotated-p commodity)
		    (get-display-precision
		     (get-basic-commodity
		      (get-referent-commodity commodity)))
		    (get-display-precision
		     (get-basic-commodity commodity)))))))

    (assert (or (null commodity-symbol)
		(> (length (commodity-symbol-name commodity-symbol)) 0)))

    (multiple-value-bind (quotient remainder)
	(truncate
	 (cond
	   ((> precision display-precision)
	    (round quantity (expt 10 (- precision display-precision))))
	   ((> display-precision precision)
	    (* quantity (expt 10 (- display-precision precision))))
	   (t
	    quantity))
	 (expt 10 display-precision))

      (let ((output
	     (with-output-to-string (buffer)
	       (flet ((maybe-gap ()
			(unless (commodity-symbol-connected-p commodity-symbol)
			  (princ #\Space buffer))))
		 (when (and (not omit-commodity-p)
			    (commodity-symbol-prefixed-p commodity-symbol))
		   (princ (commodity-name amount) buffer)
		   (maybe-gap))

		 (if (cl:minusp quantity)
		     (format buffer "-"))
		 (format buffer "~:[~,,vD~;~,,v:D~]" ;
			 (and commodity
			      (commodity-thousand-marks-p commodity))
			 (if *european-style* #\. #\,) (cl:abs quotient))

		 (unless (cl:zerop display-precision)
		   (format buffer "~C~v,'0D"
			   (if *european-style* #\, #\.)
			   display-precision (cl:abs remainder)))
      
		 (when (and (not omit-commodity-p)
			    (not (commodity-symbol-prefixed-p commodity-symbol)))
		   (maybe-gap)
		   (princ (commodity-name amount) buffer)))

	       (if (and (not omit-commodity-p)
			commodity
			(get-annotated-p commodity))
		   (format-commodity-annotation (commodity-annotation commodity)
						:output-stream buffer)))))
	(if width
	    (format output-stream "~v@A" width output)
	    (princ output output-stream)))))
  (values))

(defun compare-amounts-visually (left right)
  (declare (type (cons (or commodity null) amount) left))
  (declare (type (cons (or commodity null) amount) right))
  (if (commodity-equal (car left) (car right))
      (value-lessp* (cdr left) (cdr right))
      (commodity-lessp (car left) (car left))))

(defmethod print-value ((balance balance) &key
			(output-stream *standard-output*)
			(omit-commodity-p nil)
			(full-precision-p nil)
			(width 12)
			(latter-width nil)
			(line-feed-string (format nil "~C" #\Newline)))
  (declare (type boolean omit-commodity-p))
  (declare (type boolean full-precision-p))
  (declare (type (or fixnum null) latter-width))
  (let ((first t)
	(amounts (get-amounts-map balance)))
    (mapc #'(lambda (amount)
	      (unless first
		(princ line-feed-string output-stream))
	      (print-value (cdr amount)
			   :width (if (or first (null latter-width))
				      width latter-width)
			   :output-stream output-stream
			   :omit-commodity-p omit-commodity-p
			   :full-precision-p full-precision-p)
	      (setf first nil))
	  amounts))
  (values))

(defmethod format-value ((integer integer) &key
			 (omit-commodity-p nil)
			 (full-precision-p nil)
			 (width nil)
			 (latter-width nil)
			 (line-feed-string nil))
  (declare (ignore latter-width))
  (declare (ignore line-feed-string))
  (with-output-to-string (out)
    (print-value (integer-to-amount integer) :output-stream out
		 :omit-commodity-p omit-commodity-p
		 :full-precision-p full-precision-p
		 :width width)
    out))

(defmethod format-value ((amount amount) &key
			 (omit-commodity-p nil)
			 (full-precision-p nil)
			 (width nil)
			 (latter-width nil)
			 (line-feed-string nil))
  (declare (ignore latter-width))
  (declare (ignore line-feed-string))
  (with-output-to-string (out)
    (print-value amount :output-stream out
		 :omit-commodity-p omit-commodity-p
		 :full-precision-p full-precision-p
		 :width width)
    out))

(defmethod format-value ((balance balance) &key
			 (omit-commodity-p nil)
			 (full-precision-p nil)
			 (width nil)
			 (latter-width nil)
			 (line-feed-string (format nil "~C" #\Newline)))
  (with-output-to-string (out)
    (print-value balance :output-stream out
		 :omit-commodity-p omit-commodity-p
		 :full-precision-p full-precision-p
		 :width width
		 :latter-width latter-width
		 :line-feed-string line-feed-string)
    out))

(defun quantity-string (amount)
  (assert amount)
  (format-value amount :omit-commodity-p t :full-precision-p t))

;;;_  + Find AMOUNT of COMMODITY in a BALANCE

(defmethod amount-in-balance ((balance balance) (commodity commodity))
  (or (cdr (assoc commodity (get-amounts-map balance)))
      (unless (and *keep-annotation-prices*
		   *keep-annotation-dates*
		   *keep-annotation-tags*)
	(cdr (assoc commodity
		    (strip-annotations (get-amounts-map balance)
				       :keep-price *keep-annotation-prices*
				       :keep-date  *keep-annotation-dates*
				       :keep-tag   *keep-annotation-tags*))))))

;;;_ * COMMODITY

;;;_  + Return copy of AMOUNT without a commodity

(defun amount-sans-commodity (amount)
  (declare (type amount amount))
  (the amount
    (let ((commodity (amount-commodity amount)))
      (if commodity
	  (let ((tmp (copy-amount amount)))
	    (assert (amount-commodity tmp))
	    (setf (amount-commodity tmp) nil)
	    tmp)
	  amount))))

;;;_  - Parse commodity symbols

(declaim (inline symbol-char-invalid-p))

(defun symbol-char-invalid-p (c)
  (declare (type character c))
  (let ((code (char-code c)))
    (and (< code 256)
	 (aref *invalid-symbol-chars* code))))

(declaim (inline symbol-name-needs-quoting-p))

(defun symbol-name-needs-quoting-p (name)
  "Return T if the given symbol NAME requires quoting."
  (declare (type string name))
  (the boolean
    (loop for c across name do
	 (if (symbol-char-invalid-p c)
	     (return t)))))

(define-condition commodity-error (error) 
  ((description :reader error-description :initarg :msg))
  (:report
   (lambda (condition stream)
     (format stream "~S" (error-description condition)))))

(defun read-commodity-symbol (in)
  "Parse a commodity symbol from the input stream IN.

  This is the correct entry point for creating a new commodity symbol.

  A commodity contain any character not found in *INVALID-SYMBOL-CHARS*.  To
include such characters in a symbol name---except for #\\\", which may never
appear in a symbol name---surround the commodity name with double quotes.  It
is an error if EOF is reached without reading the ending double quote.  If the
symbol name is not quoted, and an invalid character is reading, reading from
the stream stops and the invalid character is put back."
  (declare (type stream in))
  (let ((buf (make-string-output-stream))
	needs-quoting-p)
    (if (char= #\" (peek-char nil in))
	(progn
	  (read-char in)
	  (loop
	     for c = (read-char in nil) do
	     (if c
		 (if (char= #\" c)
		     (return)
		     (progn
		       (if (symbol-char-invalid-p c)
			   (setf needs-quoting-p t))
		       (write-char c buf)))
		 (error 'commodity-error
			:msg "Quoted commodity symbol lacks closing quote"))))
	(loop
	   for c = (read-char in nil) while c do
	   (if (symbol-char-invalid-p c)
	       (progn
		 (unread-char c in)
		 (return))
	       (write-char c buf))))
    (make-commodity-symbol :name (get-output-stream-string buf)
			   :needs-quoting-p needs-quoting-p)))

;;;_  * Access commodity details (across all commodity classes)

;; The commodity and annotated-commodity classes are the main interface class
;; for dealing with commodities themselves (which most people will never do).

(defmethod commodity-base ((null null)) nil)
(defmethod commodity-base ((commodity commodity))
  (get-basic-commodity commodity))
(defmethod commodity-base ((annotated-commodity annotated-commodity))
  (get-basic-commodity (get-referent-commodity annotated-commodity)))

(defmacro commodity-indirection (name accessor &key type)
  `(progn
     (defmethod ,name ((commodity commodity))
       (the ,type
	 (,accessor (get-basic-commodity commodity))))
     (defmethod ,name ((annotated-commodity annotated-commodity))
       (the ,type
	 (,accessor (get-basic-commodity
		     (get-referent-commodity annotated-commodity)))))))

(commodity-indirection commodity-symbol get-symbol :type commodity-symbol)
(commodity-indirection commodity-description get-description :type string)
(commodity-indirection commodity-thousand-marks-p get-thousand-marks-p
		       :type boolean)
(commodity-indirection commodity-precision get-display-precision :type fixnum)

(defmethod commodity-name ((null null)) "")
(defmethod commodity-name ((commodity commodity))
  (commodity-symbol-name (get-symbol (get-basic-commodity commodity))))
(defmethod commodity-name ((annotated-commodity annotated-commodity))
  (commodity-symbol-name
   (get-symbol (get-basic-commodity
		(get-referent-commodity annotated-commodity)))))
(defmethod commodity-name ((amount amount))
  (let ((commodity (amount-commodity amount)))
    (if (and commodity (get-annotated-p commodity))
	(setf commodity (get-referent-commodity commodity)))
    (if commodity
	(if (slot-boundp commodity 'qualified-name)
	    (commodity-qualified-name commodity)
	    (let ((symbol (get-symbol (get-basic-commodity commodity))))
	      (when symbol
		(assert (not (commodity-symbol-needs-quoting-p symbol)))
		(commodity-symbol-name symbol)))))))

(defmethod display-precision ((commodity commodity))
  (the fixnum
    (get-display-precision (get-basic-commodity commodity))))
(defmethod display-precision ((annotated-commodity annotated-commodity))
  (the fixnum
    (get-display-precision (get-basic-commodity
			    (get-referent-commodity annotated-commodity)))))
(defmethod display-precision ((amount amount))
  (display-precision (amount-commodity amount)))

;;;_  + Commodity equality

(defmethod commodity-equal ((a null) (b null)) t)
(defmethod commodity-equal ((a commodity) (b null)) nil)
(defmethod commodity-equal ((a null) (b commodity)) nil)
(defmethod commodity-equal ((a commodity) (b commodity))
  "Two commodities are EQUAL if they have the same BASIC-COMMODITY.
They may be of different COMMODITY types, but this is just nomenclature
That is, USD always equals $."
  (eq (get-basic-commodity a) (get-basic-commodity b)))
(defmethod commodity-equal ((a commodity) (b annotated-commodity)) nil)
(defmethod commodity-equal ((a annotated-commodity) (b commodity)) nil)
(defmethod commodity-equal ((a annotated-commodity) (b annotated-commodity))
  (eq a b))

(defmethod commodity-equalp ((a null) (b null)) t)
(defmethod commodity-equalp ((a commodity) (b null)) nil)
(defmethod commodity-equalp ((a null) (b commodity)) nil)
(defmethod commodity-equalp ((a commodity) (b commodity))
  "Two commodities are considered EQUALP if they refer to the same base."
  (eq (get-basic-commodity a) (get-basic-commodity b)))
(defmethod commodity-equalp ((a commodity) (b annotated-commodity))
  (eq (get-basic-commodity a) (get-basic-commodity
			       (get-referent-commodity b))))
(defmethod commodity-equalp ((a annotated-commodity) (b commodity))
  (eq (get-basic-commodity
       (get-referent-commodity a)) (get-basic-commodity b)))
(defmethod commodity-equalp ((a annotated-commodity) (b annotated-commodity))
  (eq (get-basic-commodity (get-referent-commodity a))
      (get-basic-commodity (get-referent-commodity b))))

;;;_  + Function to sort commodities

(defun commodity-lessp (left right)
  "Return T if commodity LEFT should be sorted before RIGHT."
  (declare (type (or commodity annotated-commodity null) left))
  (declare (type (or commodity annotated-commodity null) right))
  (the boolean
    (block nil
      (if (and (null left) right)
	  (return t))
      (if (and left (null right))
	  (return nil))
      (if (and (null left) (null right))
	  (return t))

      (unless (commodity-equalp left right)
	(return (not (null (string-lessp (commodity-name left)
					 (commodity-name right))))))

      (let ((left-annotated-p (get-annotated-p left))
	    (right-annotated-p (get-annotated-p right)))
	(if (and (not left-annotated-p)
		 right-annotated-p)
	    (return t))
	(if (and left-annotated-p
		 (not right-annotated-p))
	    (return nil))
	(if (and (not left-annotated-p)
		 (not right-annotated-p))
	    (return t)))

      (let ((left-annotation (commodity-annotation left))
	    (right-annotation (commodity-annotation right)))

	(let ((left-price (annotation-price left-annotation))
	      (right-price (annotation-price right-annotation)))
	  (if (and (not left-price) right-price)
	      (return t))
	  (if (and left-price (not right-price))
	      (return nil))
	  (if (and left-price right-price)
	      (if (commodity-equal (amount-commodity left-price)
				   (amount-commodity right-price))
		  (return (value< left-price right-price))
		  ;; Since we have two different amounts, there's really no way
		  ;; to establish a true sorting order; we'll just do it based
		  ;; on the numerical values.
		  (return (< (amount-quantity left-price)
			     (amount-quantity right-price))))))

	(let ((left-date (annotation-date left-annotation))
	      (right-date (annotation-date right-annotation)))
	  (if (and (not left-date) right-date)
	      (return t))
	  (if (and left-date (not right-date))
	      (return nil))
	  (when (and left-date right-date)
	    (return (coerce (local-time:local-time< left-date right-date)
			    'boolean))))

	(let ((left-tag (annotation-tag left-annotation))
	      (right-tag (annotation-tag right-annotation)))
	  (if (and (not left-tag) right-tag)
	      (return t))
	  (if (and left-tag (not right-tag))
	      (return nil))
	  (when (and left-tag right-tag)
	    (return (string-lessp left-tag right-tag)))))

      (return t))))

;;;_  + Current and historical market values (prices) for a commodity

(defun add-price (commodity price &optional fixed-time)
  (declare (type (or commodity annotated-commodity null) commodity))
  (declare (type amount price))
  (declare (type (or fixed-time null) fixed-time))
  (when commodity
    (let ((base (commodity-base commodity))
	  (pricing-entry
	   (make-pricing-entry :moment (or fixed-time (local-time:now))
			       :price price)))
      (if (not (get-price-history base))
	  (setf (get-price-history base) (rbt:nil-tree)))
      (let ((history (get-price-history base)))
	(multiple-value-bind (new-root node-inserted-or-found item-already-in-p)
	    (rbt:insert-item pricing-entry history :key 'pricing-entry-moment)
	  (if item-already-in-p
	      (setf (pricing-entry-price (rbt:node-item node-inserted-or-found))
		    price))
	  (setf (get-price-history base) new-root)))
      price)))

(defun remove-price (commodity fixed-time)
  (declare (type (or commodity annotated-commodity null) commodity))
  (declare (type fixed-time fixed-time))
  (when commodity
    (let ((base (commodity-base commodity)))
      (when (get-price-history base)
	(multiple-value-bind (new-root node-deleted-p)
	    (rbt:delete-item fixed-time (get-price-history base)
			     :key 'pricing-entry-moment)
	  (setf (get-price-history base) new-root)
	  node-deleted-p)))))

(defun find-nearest (it root &key (test #'<=) (key #'identity))
  "Find an item in the tree which is closest to IT according to TEST.
For the default, <=, this means no other item will be more less than IT in the
tree than the one found."
  (declare (type fixed-time it))
  (declare (type rbt:rbt-node root))
  (the (or pricing-entry null)
    (loop
       with p = root
       with last-found = nil
       named find-loop
       finally (return-from find-loop
		 (and last-found (rbt:node-item last-found)))
       while (not (rbt:rbt-null p))
       do
       (if (funcall test (funcall key (rbt:node-item p)) it)
	   (progn
	     ;; If the current item meets the test, it may be the one we're
	     ;; looking for.  However, there might be something closer to the
	     ;; right -- though definitely not to the left.
	     (setf last-found p p (rbt:right p)))
	   ;; If the current item does not meet the test, there might be a
	   ;; candidate to the left -- but definitely not the right.
	   (setf p (rbt:left p))))))

(defmethod market-value ((commodity commodity) &optional fixed-time)
  (declare (type (or commodity annotated-commodity null) commodity))
  (declare (type (or fixed-time null) fixed-time))

  ;; jww (2007-12-03): This algorithm needs extensive testing
  (let* ((base (commodity-base commodity))
	 (history (get-price-history base)))
    (when history
      (if (null fixed-time)
	  (progn
	    (loop
	       while (not (rbt:rbt-null (rbt:right history)))
	       do (setf history (rbt:right history)))
	    (assert history)
	    (rbt:node-item history))
	  (find-nearest fixed-time history
			:key 'pricing-entry-moment)))))

(defmethod market-value ((annotated-commodity annotated-commodity) &optional fixed-time)
  (market-value (get-referent-commodity annotated-commodity) fixed-time))

(defmethod market-value ((amount amount) &optional fixed-time)
  (let ((commodity (amount-commodity amount)))
    (when commodity
      (let ((value (market-value commodity fixed-time)))
	(if value
	    (value-round* (multiply* value amount)))))))

(defmethod market-value ((balance balance) &optional fixed-time)
  (let ((value-balance (make-instance 'balance)))
    (mapc #'(lambda (entry)
	      (add* value-balance (market-value (cdr entry) fixed-time)))
	  (get-amounts-map balance))
    value-balance))

;;;_  + Exchange a commodity

(defun exchange-commodity (amount price &key
			   (sale nil) (moment nil) (note nil))
  (declare (type amount amount))
  (declare (type amount price))
  (declare (type boolean sale))
  (declare (type (or fixed-time null) moment))
  (declare (type (or string null) note))
  (let ((current-annotation (commodity-annotation
			     (amount-commodity amount)))
	(per-share-price (divide price amount)))
    (values
     (if sale
	 (and current-annotation
	      (subtract price
			(multiply (annotation-price current-annotation)
				  amount)))
	 (annotate-commodity
	  amount
	  (make-commodity-annotation :price per-share-price
				     :date moment
				     :tag note))))))

(defun purchase-commodity (amount price &key (moment nil) (note nil))
  (exchange-commodity amount price :moment moment :note note))

(defun sell-commodity (amount price &key (moment nil) (note nil))
  (exchange-commodity amount price :sale t :moment moment :note note))

;;;_ * COMMODITY-POOL

;;;_  - Commodity creation and pool management

;; All commodities are allocated within a pool, which can be used to look them
;; up.

(defun reset-commodity-pool (&optional pool)
  (setf *default-commodity-pool* (or pool (make-commodity-pool))))

;;;_   : COMMODITY

(defmacro pushend (item the-list &optional final-cons)
  (let ((items-sym (gensym))
	(new-cons-sym (gensym)))
    `(let* ((,items-sym ,the-list)
	    (,new-cons-sym (list ,item)))
       (if ,items-sym
	   ,(if final-cons
		`(setf (cdr ,final-cons) ,new-cons-sym
		       ,final-cons ,new-cons-sym)
		`(nconc ,items-sym ,new-cons-sym))
	   (progn
	     ,`(setf ,the-list ,new-cons-sym)
	     ,(if final-cons
		  `(setf ,final-cons ,new-cons-sym))))
       (car ,new-cons-sym))))

(defun create-commodity (name &key (pool *default-commodity-pool*))
  "Create a COMMODITY after the symbol name found by parsing NAME.

  The NAME can be either a string or an input stream, or nil, in which case
the name is read from *STANDARD-INPUT*.

  The argument :pool specifies the commodity pool which will maintain this
commodity, and by which other code may access it again.  The resulting
COMMODITY object is returned."
  (declare (type (or string commodity-symbol) name))
  (declare (type commodity-pool pool))
  (the commodity
    (let* ((symbol (if (stringp name)
		       (with-input-from-string (in name)
			 (read-commodity-symbol in))
		       name))
	   (base (make-basic-commodity :symbol symbol))
	   (commodity (make-instance 'commodity :basic-commodity base
						:commodity-pool pool))
	   (symbol-name (commodity-symbol-name symbol)))

      (if (commodity-symbol-needs-quoting-p symbol)
	  (setf (commodity-qualified-name commodity)
		(concatenate 'string "\"" symbol-name "\"")))
      
      (let ((names-map (commodity-pool-by-name-map pool)))
	(assert (not (gethash symbol-name names-map)))
	(setf (gethash symbol-name names-map) commodity)))))

(defun find-commodity (name &key (create-if-not-exists-p nil)
		       (pool *default-commodity-pool*))
  "Find a COMMODITY identifier by the symbol name found by parsing NAME.

  The NAME can be either a string or an input stream, or nil, in which case
the name is read from *STANDARD-INPUT*.

  The argument :POOL specifies the commodity pool which will maintain this
commodity, and by which other code may access it again.

  The argument :CREATE-IF-NOT-EXISTS-P indicates whether a new commodity
should be created if one cannot already be found.

  The return values are: COMMODITY or NIL, NEWLY-CREATED-P"
  (declare (type (or string commodity-symbol) name))
  (declare (type boolean create-if-not-exists-p))
  (declare (type commodity-pool pool))
  (the (values (or commodity null) boolean)
    (let ((by-name-map (commodity-pool-by-name-map pool)))
      (multiple-value-bind (entry present-p)
	  (gethash (if (stringp name)
		       name
		       (commodity-symbol-name name)) by-name-map)
	(if present-p
	    (values entry nil)
	    (if create-if-not-exists-p
		(values
		 (create-commodity name :pool pool)
		 t)
		(values nil nil)))))))

;;;_   : ANNOTATED-COMMODITY

(defun make-qualified-name (commodity commodity-annotation)
  (declare (type commodity commodity))
  (declare (type commodity-annotation commodity-annotation))

  (if (and (annotation-price commodity-annotation)
	   (< (sign (annotation-price commodity-annotation)) 0))
      (error 'amount-error :msg "A commodity's price may not be negative"))

  (with-output-to-string (out)
    (princ (commodity-symbol-name
	    (commodity-symbol commodity)) out)
    (format-commodity-annotation commodity-annotation :output-stream out)))

(defun create-annotated-commodity (commodity details qualified-name)
  "Create an ANNOTATED-COMMODITY which annotates COMMODITY.

The NAME can be either a string or a COMMODITY-SYMBOL."
  (declare (type commodity commodity))
  (declare (type commodity-annotation details))
  (declare (type string qualified-name))
  (the annotated-commodity
    (let ((annotated-commodity
	   (make-instance 'annotated-commodity
			  :referent-commodity commodity
			  :annotation details
			  :qualified-name qualified-name))
	  (pool (get-commodity-pool commodity)))
      (let ((names-map (commodity-pool-by-name-map pool)))
	(assert (not (gethash qualified-name names-map)))
	(setf (gethash qualified-name names-map) annotated-commodity)))))

(defun find-annotated-commodity (name-or-commodity details
				 &key (create-if-not-exists-p nil)
				 (pool *default-commodity-pool*))
  "Find an annotated commodity matching the commodity symbol NAME,
which may be a STRING or a COMMODITY-SYMBOL, and given set of commodity
DETAILS, of type COMMODITY-ANNOTATION.

  Returns two values: COMMODITY or NIL, NEWLY-CREATED-P"
  (declare (type (or string commodity-symbol commodity)
		 name-or-commodity))
  (declare (type commodity-annotation details))
  (declare (type boolean create-if-not-exists-p))
  (declare (type commodity-pool pool))
  (assert (not (commodity-annotation-empty-p details)))
  (let ((commodity
	 (if (typep name-or-commodity 'commodity)
	     (progn
	       (assert (not (get-annotated-p name-or-commodity)))
	       name-or-commodity)
	     (find-commodity name-or-commodity
			     :create-if-not-exists-p create-if-not-exists-p
			     :pool pool))))
    (if commodity
	(let* ((annotated-name (make-qualified-name commodity details))
	       (annotated-commodity
		(find-commodity annotated-name :pool pool)))
	  (if annotated-commodity
	      (progn
		(assert (get-annotated-p annotated-commodity))
		(assert
		 (commodity-annotation-equal
		  details (commodity-annotation annotated-commodity)))
		(values annotated-commodity nil))
	      (if create-if-not-exists-p
		  (values
		   (create-annotated-commodity commodity details
					       annotated-name)
		   t))))
	(values nil nil))))

;;;_ * ANNOTATED-COMMODITY

;;;_  - Read commodity annotation from a stream

(defun read-until (in char &optional error-message)
  (declare (type stream in))
  (declare (type character char))
  (declare (type (or string null) error-message))
  (with-output-to-string (text)
    (loop
       for c = (read-char in nil)
       while (if c
		 (char/= char c)
		 (if error-message
		     (error 'amount-error :msg error-message)))
       do (write-char c text))))

(defun read-commodity-annotation (in)
  (declare (type stream in))
  (let ((annotation (make-commodity-annotation)))
    (loop
       for c = (peek-char t in nil) while c do
       (cond
	 ((char= c #\{)
	  (if (annotation-price annotation)
	      (error 'amount-error :msg
		     "Commodity annotation specifies more than one price"))

	  (read-char in)
	  (let* ((price-string
		  (read-until in #\} "Commodity price lacks closing brace"))
		 (tmp-amount (parse-amount* price-string)))

	    ;; Since this price will maintain its own precision, make sure
	    ;; it is at least as large as the base commodity, since the user
	    ;; may have only specified {$1} or something similar.
	    (let ((commodity (amount-commodity tmp-amount)))
	      (if (and commodity
		       (< (amount-precision tmp-amount)
			  (display-precision commodity)))
		  (setf tmp-amount
			(value-round* tmp-amount
				      (display-precision commodity)))))

	    (setf (annotation-price annotation) tmp-amount)))

	 ((char= c #\[)
	  (if (annotation-date annotation)
	      (error 'amount-error :msg
		     "Commodity annotation specifies more than one date"))

	  (read-char in)
	  (let* ((date-string
		  (read-until in #\] "Commodity date lacks closing bracket"))
		 (tmp-date (strptime date-string)))
	    (setf (annotation-date annotation) tmp-date)))

	 ((char= c #\()
	  (if (annotation-tag annotation)
	      (error 'amount-error :msg
		     "Commodity annotation specifies more than one tag"))

	  (read-char in)
	  (setf (annotation-tag annotation)
		(read-until in #\) "Commodity tag lacks closing parenthesis")))

	 (t
	  (return))))
    (the commodity-annotation
      annotation)))

;;;_  - Format commodity annotation to a string

(defun format-commodity-annotation (annotation &key
				    (output-stream *standard-output*))
  "Return the canonical annotation string for ANNOTATION.

  A fully annotated commodity always follows the form:

    [-]SYMBOL <VALUE> {PRICE} [DATE] (TAG)
or
    <VALUE> SYMBOL {PRICE} [DATE] (TAG)

  If a particular annotation is not present, those sections is simply dropped
from the string, for example:

    <VALUE> SYMBOL {PRICE}"
  (declare (type commodity-annotation annotation))
  (declare (type stream output-stream))
  (format output-stream "~:[~; {~:*~A}~]~:[~; [~:*~A]~]~:[~; (~:*~A)~]"
	  (format-value (annotation-price annotation))
	  (and (annotation-date annotation)
	       (strftime (annotation-date annotation)))
	  (annotation-tag annotation)))

;;;_  + Unary truth tests

(defmethod commodity-annotated-p ((commodity commodity))
  (get-annotated-p commodity))
(defmethod commodity-annotated-p ((amount amount))
  (get-annotated-p (amount-commodity amount)))

;;;_  + Annotate the commodity of a COMMODITY or AMOUNT

(defmethod annotate-commodity ((commodity commodity)
			       (details commodity-annotation))
  (find-annotated-commodity commodity details :create-if-not-exists-p t))

(defmethod annotate-commodity ((amount amount)
			       (details commodity-annotation))
  (let ((commodity (amount-commodity amount)))
    (unless commodity
      (error 'amount-error :msg
	     "Cannot annotate an amount which has no commodity"))
    (let ((referent commodity))
      (if (get-annotated-p referent)
	  (setf referent (get-referent-commodity referent)))

      (let ((annotated-commodity
	     (find-annotated-commodity referent details
				       :create-if-not-exists-p t)))
	(let ((tmp (copy-amount amount)))
	  (setf (amount-commodity tmp) annotated-commodity)
	  tmp)))))

;;;_  + Access a commodity's annotation

(defmethod commodity-annotation ((commodity commodity))
  nil)
(defmethod commodity-annotation ((annotated-commodity annotated-commodity))
  (get-annotation annotated-commodity))
(defmethod commodity-annotation ((amount amount))
  ;; This calls the appropriate generic function
  (commodity-annotation (amount-commodity amount)))

;;;_  + Commodity annotation tests

(defmethod commodity-annotation-empty-p ((annotation commodity-annotation))
  (not (or (annotation-price annotation)
	   (annotation-date annotation)
	   (annotation-tag annotation))))

(defmethod commodity-annotation-equal ((a commodity-annotation)
				       (b commodity-annotation))
  (let ((price-a (annotation-price a))
	(price-b (annotation-price b))
	(date-a (annotation-date a))
	(date-b (annotation-date b))
	(tag-a (annotation-tag a))
	(tag-b (annotation-tag b)))
    (and (or (and (null price-a) (null price-b))
	     (and price-a price-b
		  (value= price-a price-b)))
	 (or (and (null date-a) (null date-b))
	     (and date-a date-b
		  (local-time:local-time= date-a date-b)))
	 (or (and (null tag-a) (null tag-b))
	     (and tag-a tag-b
		  (string= tag-a tag-b))))))

;;;_  + Strip commodity annotations

;; annotated-commodity's are references to other commodities (which in turn
;; reference a basic-commodity) which carry along additional contextual
;; information relating to a point in time.

(defmethod strip-annotations ((commodity commodity)
			      &key keep-price keep-date keep-tag)
  (declare (type boolean keep-price))
  (declare (type boolean keep-date))
  (declare (type boolean keep-tag))
  (declare (ignore keep-price))
  (declare (ignore keep-date))
  (declare (ignore keep-tag))
  (assert (not (get-annotated-p commodity)))
  commodity)

(defmethod strip-annotations ((annotated-commodity annotated-commodity)
			      &key keep-price keep-date keep-tag)
  (declare (type boolean keep-price))
  (declare (type boolean keep-date))
  (declare (type boolean keep-tag))
  (assert (get-annotated-p annotated-commodity))
  (let* ((annotation (commodity-annotation annotated-commodity))
	 (price (annotation-price annotation))
	 (date (annotation-date annotation))
	 (tag (annotation-tag annotation)))
    (if (and (or keep-price (null price))
	     (or keep-date (null date))
	     (or keep-tag (null tag)))
	annotated-commodity
	(let ((tmp (make-instance 'annotated-commodity)))
	  (setf (get-referent-commodity tmp)
		(get-referent-commodity annotated-commodity))
	  (let ((new-ann (make-commodity-annotation)))
	    (setf (get-annotation tmp) new-ann)
	    (if keep-price
		(setf (annotation-price new-ann) price))
	    (if keep-date
		(setf (annotation-date new-ann) date))
	    (if keep-tag
		(setf (annotation-tag new-ann) tag)))
	  (if (commodity-annotation-empty-p tmp)
	      (get-referent-commodity tmp)
	      tmp)))))

(defmethod strip-annotations ((amount amount)
			      &key keep-price keep-date keep-tag)
  (declare (type boolean keep-price))
  (declare (type boolean keep-date))
  (declare (type boolean keep-tag))
  (the amount
    (if (and keep-price keep-date keep-tag)
	amount
	(let ((commodity (amount-commodity amount)))
	  (if (or (null commodity)
		  (not (get-annotated-p commodity))
		  (and keep-price keep-date keep-tag))
	      amount
	      (let ((tmp (copy-amount amount)))
		(setf (amount-commodity tmp)
		      (strip-annotations commodity
					 :keep-price keep-price
					 :keep-date keep-date
					 :keep-tag keep-tag))
		tmp))))))

(defmethod strip-annotations ((balance balance)
			      &key keep-price keep-date keep-tag)
  (declare (type boolean keep-price))
  (declare (type boolean keep-date))
  (declare (type boolean keep-tag))
  (the balance
    (if (and keep-price keep-date keep-tag)
	balance
	(let ((stripped-balance (make-instance 'balance)))
	  (mapc #'(lambda (entry)
		    (add* stripped-balance
			  (strip-annotations (cdr entry)
					     :keep-price keep-price
					     :keep-date  keep-date
					     :keep-tag   keep-tag)))
		(get-amounts-map balance))
	  stripped-balance))))

(provide 'cambl)

;; cambl.lisp ends here
