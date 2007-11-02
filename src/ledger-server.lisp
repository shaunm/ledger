;; ledger-server.lisp

(declaim (optimize (safety 3) (debug 3)))

(defpackage :ledger-server
  (:use :common-lisp :cambl :ledger :cl-ppcre :hunchentoot :cl-who))

(in-package :ledger-server)

(defmacro with-html (&body body)
  `(with-html-output-to-string (*standard-output* nil :prologue t)
     ,@body))

(define-easy-handler (easy-demo :uri "/"
                                :default-request-type :post)
    ((journal-path :parameter-type 'string))
  (with-html
    (:html
     (:head (:title "Ledger Register"))
     (:body
      :style "margin: 50px"
      (:p (:form
	   :method :post
	   (:table
	    :border 0 :cellpadding 5 :cellspacing 0
	    (:tr
	     (:td :style "text-align: right"
		  (str "Journal path:"))
	     (:td (:input
		   :type :text
		   :style "width: 30em"
		   :name "journal-path"
		   :value (or journal-path "sample.dat")))
	     (:td (:input :type :submit :value "Register"))))))
      (when journal-path
	(with-open-file (debug-stream #p"/tmp/debug" :direction :output)
	  (let ((binder (binder journal-path)))
	    (format debug-stream "binder: ~S~%" binder)
	    (dolist (journal (binder-journals binder))
	      (format debug-stream "journal: ~S~%" journal)
	      (htm
	       (:p
		(:table
		 :border 1 :cellpadding 5 :cellspacing 2
		 :style "margin: 10px 0 0 5%"
		 (:thead
		  (:tr (:th "Payee") (:th "Amount") (:th "Total")))
		 (let ((running-total (integer-to-amount 0))
		       (zero-amount (integer-to-amount 0)))
		   (dolist (entry (journal-entries journal))
		     (format debug-stream "entry: ~S~%" entry)
		     (dolist (xact (entry-transactions entry))
		       (format debug-stream "xact: ~S~%" xact)
		       (let ((amt (xact-amount xact)))
			 (htm
			  (:tr
			   (:td (str (entry-payee entry)))
			   (:td :style "text-align: right; padding-left: 2em"
				(print-value (if amt amt zero-amount)))
			   (:td
			    :style "text-align: right; padding-left: 2em"
			    (print-value
			     (if amt
				 (setq running-total
				       (add* running-total amt))
				 running-total)
			     :line-feed-string "<br />")))))))
		   (htm
		    (:tfoot
		     (:tr
		      (:td :colspan 3
			   :style "text-align: right; padding-left: 2em;
                                 font-weight: bold"
			   (print-value running-total
					:line-feed-string "<br />")))))))))))))))))

(defun hello-world ()
  (with-html
    (:html
     (:head (:title "Welcome to your Finances"))
     (:body
      (:h1 "Hello, world!")
      (:p "This is the canonical hello message.")))))

(setq *dispatch-table*
      (list #'dispatch-easy-handlers
	    (create-prefix-dispatcher "/hello" #'hello-world)
	    #'default-dispatcher))

(setq *show-lisp-errors-p* t
      *show-lisp-backtraces-p* t)

;; ledger-server.lisp ends here