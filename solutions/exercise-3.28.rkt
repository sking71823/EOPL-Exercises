#lang eopl

;; Exercise 3.28 [★★] Dynamic binding (or dynamic scoping) is an alternative design for procedures, in which the
;; procedure body is evaluated in an environment obtained by extending the environment at the point of call. For example
;; in
;;
;;     let a = 3
;;     in let p = proc (x) -(x,a)
;;            a = 5
;;        in -(a,(p 2))
;;
;; the a in the procedure body would be bound to 5, not 3. Modify the language to use dynamic binding. Do this twice,
;; once using a procedural representation for procedures, and once using a data-structure representation.

;; Environments.

(define empty-env-record? null?)

(define environment?
  (lambda (x)
    (or (empty-env-record? x)
        (and (pair? x)
             (symbol? (car (car x)))
             (expval? (cadr (car x)))
             (environment? (cdr x))))))

(define empty-env?
  (lambda (x)
    (empty-env-record? x)))

(define extended-env-record->sym
  (lambda (r)
    (car (car r))))

(define extended-env-record->val
  (lambda (r)
    (cadr (car r))))

(define extended-env-record->old-env
  (lambda (r)
    (cdr r)))

(define apply-env
  (lambda (env search-sym)
    (if (empty-env? env)
        (eopl:error 'apply-env "No binding for ~s" search-sym)
        (let ([sym (extended-env-record->sym env)]
              [val (extended-env-record->val env)]
              [old-env (extended-env-record->old-env env)])
          (if (eqv? search-sym sym)
              val
              (apply-env old-env search-sym))))))

(define extended-env-record
  (lambda (sym val old-env)
    (cons (list sym val) old-env)))

(define extend-env
  (lambda (sym val old-env)
    (extended-env-record sym val old-env)))

(define empty-env-record
  (lambda ()
    '()))

(define empty-env
  (lambda ()
    (empty-env-record)))

(define init-env empty-env)

;; Data structures.

(define the-lexical-spec
  '([whitespace (whitespace) skip]
    [comment ("%" (arbno (not #\newline))) skip]
    [identifier (letter (arbno (or letter digit "_" "-" "?"))) symbol]
    [number (digit (arbno digit)) number]
    [number ("-" digit (arbno digit)) number]))

(define the-grammar
  '([program (expression) a-program]
    [expression (number) const-exp]
    [expression ("-" "(" expression "," expression ")") diff-exp]
    [expression ("zero?" "(" expression ")") zero?-exp]
    [expression ("if" expression "then" expression "else" expression) if-exp]
    [expression (identifier) var-exp]
    [expression ("let" (arbno identifier "=" expression) "in" expression) let-exp]
    [expression ("proc" "(" (separated-list identifier ",") ")" expression) proc-exp]
    [expression ("(" expression (arbno expression) ")") call-exp]))

(sllgen:make-define-datatypes the-lexical-spec the-grammar)

(define-datatype proc proc?
  [procedure [vars (list-of symbol?)]
             [body expression?]])

(define-datatype expval expval?
  [num-val [value number?]]
  [bool-val [boolean boolean?]]
  [proc-val [proc proc?]])

(define expval-extractor-error
  (lambda (variant value)
    (eopl:error 'expval-extractors "Looking for a ~s, found ~s"
                variant value)))

(define expval->num
  (lambda (v)
    (cases expval v
      [num-val (num) num]
      [else (expval-extractor-error 'num v)])))

(define expval->bool
  (lambda (v)
    (cases expval v
      [bool-val (bool) bool]
      [else (expval-extractor-error 'bool v)])))

(define expval->proc
  (lambda (v)
    (cases expval v
      [proc-val (proc) proc]
      [else (expval-extractor-error 'proc v)])))

;; Helpers.

(define apply-procedure
  (lambda (proc1 vals env)
    (cases proc proc1
      [procedure (vars body) (value-of body
                                       (let loop ([env env]
                                                  [vars vars]
                                                  [vals vals])
                                         (if (null? vars)
                                             (if (null? vals)
                                                 env
                                                 (eopl:error 'apply-procedure "Too many arguments."))
                                             (if (null? vals)
                                                 (eopl:error 'apply-procedure "Not enough arguments.")
                                                 (loop (extend-env (car vars) (car vals) env)
                                                       (cdr vars)
                                                       (cdr vals))))))])))

;; Interpreter.

(define value-of
  (lambda (exp env)
    (cases expression exp
      [const-exp (num) (num-val num)]
      [var-exp (var) (apply-env env var)]
      [diff-exp (exp1 exp2) (let ([val1 (value-of exp1 env)]
                                  [val2 (value-of exp2 env)])
                              (let ([num1 (expval->num val1)]
                                    [num2 (expval->num val2)])
                                (num-val (- num1 num2))))]
      [zero?-exp (exp1) (let ([val1 (value-of exp1 env)])
                          (let ([num1 (expval->num val1)])
                            (if (zero? num1)
                                (bool-val #t)
                                (bool-val #f))))]
      [if-exp (exp1 exp2 exp3) (let ([val1 (value-of exp1 env)])
                                 (if (expval->bool val1)
                                     (value-of exp2 env)
                                     (value-of exp3 env)))]
      [let-exp (vars exps body) (value-of body
                                          (let loop ([env env]
                                                     [vars vars]
                                                     [vals (map (lambda (e)
                                                                  (value-of e env))
                                                                exps)])
                                            (if (null? vars)
                                                env
                                                (loop (extend-env (car vars) (car vals) env)
                                                      (cdr vars)
                                                      (cdr vals)))))]
      [proc-exp (vars body) (proc-val (procedure vars body))]
      [call-exp (rator rands) (let ([proc (expval->proc (value-of rator env))]
                                    [args (map (lambda (rand)
                                                 (value-of rand env))
                                               rands)])
                                (apply-procedure proc args env))])))

;; Interfaces.

(define value-of-program
  (lambda (pgm)
    (cases program pgm
      (a-program (exp1)
                 (value-of exp1 (init-env))))))

(define scan&parse
  (sllgen:make-string-parser the-lexical-spec the-grammar))

(define run
  (lambda (string)
    (value-of-program (scan&parse string))))

(provide num-val bool-val proc-val run)
