#!/usr/bin/guile \
-L . -s
!#

(use-modules (srfi srfi-202))

;; Before showing the capabilities of SRFI-202,
;; we're going to build a little unit test framework
;; for ourselves. The main interface to the framework
;; will be the "e.g." form, whose main use is going to
;; be:

;; (e.g. <expression> ===> <value>)

;; which checks whether <expression> evaluates to <value>,
;; and reports an error if that's not the case.

;; Moreover, since Scheme expressions can in general have
;; more (or less) than one value, we allow the usages:

;; (e.g. <expression> ===> <values> ...)

;; where <values> ... is a sequence of zero or more
;; literals.

(define-syntax e.g.
  (syntax-rules (===>)
    ((e.g. <expression> ===> <values> ...)
     (call-with-values (lambda () <expression>)
       (lambda results
	 (if (equal? results '(<values> ...))
	     (apply values results)
	     (error '(<expression> ===> <values> ...)
		    results)))))
    ))

;; The SRFI-202 should be backwards compatible with
;; SRFI-2, including the following use cases:

;; if the 'claws' do not stand on the way, the empty
;; body evaluates to #t

(e.g.
 (and-let* ()) ===> #t)

(e.g.
 (and-let* ((even-two (even? 2)))) ===> #t)

(e.g.
 (and-let* ((b+ (memq 'b '(a b c))))) ===> #t)

;; presence of a false binding evaluates to #f:

(e.g.
 (and-let* ((even-one (even? 1))) 'body) ===> #f)

;; if we don't want to use the result, we can skip
;; the variable name:

(e.g.
 (and-let* (((even? 1))) 'body) ===> #f)

;; successfully passing the claws causes the and-let*
;; expression to have the value(s) of its body:

(e.g.
 (and-let* ((even-two (even? 2)))
   'body) ===> body)

(e.g.
 (and-let* ((b+ (memq 'b '(a b c))))
   b+) ===> (b c))

(e.g.
 (and-let* ((abc '(a b c))
	    (b+ (memq 'b abc))
	    (c+ (memq 'c abc))
	    ((eq? (cdr b+) c+)))
   (values b+ c+)) ===> (b c) (c))

(e.g.
 (and-let* () (values 1 2)) ===> 1 2)

;; The novel parts of SRFI-202 compared to
;; SRFI-2 are: the support for multiple values
;; combined with the support for pattern matching.

;; Multiple values can be handled in two ways:
;; either by passing the additional idenifiers/patterns
;; directly after the first one

(e.g.
 (and-let* ((a b (values 1 2)))) ===> #t)

;; or by using the "values" keyword

(e.g.
 (and-let* (((values a b) (values 1 2)))) ===> #t)

;; (mind that the result of combining those two methods
;; is unspecified, and in principle they should not be
;; combined)

;; The key difference between those two methods is that
;; in the first, the additional return values are simply
;; ignored

(e.g.
 (and-let* ((a b (values 1 2 3)))) ===> #t)

;; whereas in the second, the presence of additional
;; values causes the form to "short-circuit":

(e.g.
 (and-let* (((values a b) (values 1 2 3)))) ===> #f)

;; However, the second method allows to capture the
;; remaining values in a list:

(e.g.
 (and-let* (((values a b . c) (values 1 2 3)))
   (values a b c)) ===> 1 2 (3))

;; Another, more subtle difference is that, if the
;; first method of capturing multiple values is used,
;; and the first pattern is an identifier, then
;; the value of the variable represented by
;; that identifier must be non-#f to succeed

(e.g.
 (and-let* ((a b (values #f #t)))) ===> #f)

;; whereas, if the "values" keyword is used, this is
;; not the case:

(e.g.
 (and-let* (((values a b) (values #f #t)))) ===> #t)

;; If one finds this behavior undesirable, then
;; in the first case, one can either use a trivial
;; pattern in the position of the first received value

(e.g.
 (and-let* ((`,a b (values #f #t)))) ===> #t)

;; or

(e.g.
 (and-let* (((or a) b (values #f #t)))) ===> #t)

;; or -- if the value is known to be #f -- to express
;; that explicitly without making a binding

(e.g.
 (and-let* ((#f b (values #f #t)))) ===> #t)

;; and in the second case, one needs to add a guard
;; if they want to short-circuit the sequence:

(e.g.
 (and-let* (((values a b) (values #f #t))
	    (a))) ===> #f)

;; This SRFI doesn't specify the pattern matcher
;; to be used for destructuring. Here, we assume
;; Guile's (ice-9 match) module that was used for
;; the underlying implementation (the Wright-Cartwright
;; -Shinn matcher, described by SRFI-200 and SRFI-204),
;; but any matcher that comes with a particular Scheme
;; implementation or that is widely recognized by some
;; Scheme community should be fine.

;; SRFI-202 assumes that a match failure causes
;; the form to short-circuit/fail:

(e.g.
 (and-let* ((`(,x . ,y) '()))) ===> #f)

(e.g.
 (and-let* ((`(,x ,y) '(1 2 3)))) ===> #f)

(e.g.
 (and-let* ((5 (+ 2 2)))) ===> #f)

(e.g.
 (and-let* ((#t #f #t (values #f #t #f)))) ===> #f)

;; on the other hand, a successful match causes
;; the variables to be bound at later scopes:

(e.g.
 (and-let* ((`(,x ,y) '(2 3))
	    (x+y (+ x y))
	    ((odd? x+y))
	    (5 x+y))
   x) ===> 2)
