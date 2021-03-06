;; This file is part of Guile-WM.

;;    Guile-WM is free software: you can redistribute it and/or modify
;;    it under the terms of the GNU General Public License as published by
;;    the Free Software Foundation, either version 3 of the License, or
;;    (at your option) any later version.

;;    Guile-WM is distributed in the hope that it will be useful,
;;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;    GNU General Public License for more details.

;;    You should have received a copy of the GNU General Public License
;;    along with Guile-WM.  If not, see <http://www.gnu.org/licenses/>.

(define-module (guile-wm shared)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-9 gnu)
  #:use-module (xcb xml)
  #:use-module (xcb xml xproto)
  #:use-module (guile-wm log)
  #:export (use-wm-modules)
  #:replace (with-input-from-string make-wm-hook
              wm-init))

(define-record-type wm-hook
  (make-wm-hook-inner arity procs)
  wm-hook?
  (arity wm-hook-arity)
  (procs wm-hook-procs set-wm-hook-procs!))

(set-record-type-printer!
 wm-hook
 (lambda (r port)
   (format port "#<wm-hook ~a" (wm-hook-arity r))
   (for-each
    (lambda (proc)
      (if (procedure-name proc) (format port " ~a" (procedure-name proc)) " ?"))
    (wm-hook-procs r))
   (format port ">")))

(define-public (wm-hook-empty? hook)
  (null? (wm-hook-procs hook)))

(define* (make-wm-hook #:optional (arity 0))
  (make-wm-hook-inner arity '()))

(define-public (add-wm-hook! hook proc)
  (if (not (= (car (procedure-minimum-arity proc)) (wm-hook-arity hook)))
      (error "wm-hook: proc and hook's arity do not match"))
  (if (not (memq proc (wm-hook-procs hook)))
      (set-wm-hook-procs! hook (cons proc (wm-hook-procs hook))))
  *unspecified*)

(define-public (remove-wm-hook! hook proc)
  (set-wm-hook-procs! hook (delq proc (wm-hook-procs hook)))
  *unspecified*)

(define-public (reset-wm-hook! hook)
  (set-wm-hook-procs! hook '())
  *unspecified*)

(define-public (run-wm-hook hook . args)
  (if (not (= (length args) (wm-hook-arity hook)))
      (error "wm-hook: Wrong length argument list"))
  (for-each (lambda (proc) (apply proc args)) (wm-hook-procs hook)))

(define-public current-root (make-parameter #f))
(define-public current-screen (make-parameter #f))

(define module-init-thunks (make-hash-table))

(define-syntax wm-init
  (syntax-rules ()
   "Register the current module so that it can be initialized once the
window manager is running. THUNK will be executed after
`current-xcb-connection' is set to the window manager's X connection."
   ((_ t) (define %guile-wm-init-proc t))))

(define-syntax use-wm-modules
  (syntax-rules ()
    ((_ m ...)
     (begin
       (let ((int (resolve-interface (if (list? 'm) 'm '(guile-wm module m))))
             (mod (resolve-module (if (list? 'm) 'm '(guile-wm module m)))))
         (module-use! (current-module) int)
         (if (module-defined? mod '%guile-wm-init-proc)
             (hashq-set!
              module-init-thunks
              mod
              (module-ref mod '%guile-wm-init-proc)))) ...))))

(define-public (init-guile-wm-modules!)
  "Call all of the initialization thunks for registered window manager
modules."
  (for-each
   (lambda (kv)
     (log! (format #f "Initializing module: ~a" (module-name (car kv))))
     ((cdr kv)))
   (hash-map->list cons module-init-thunks)))

;; This procedure is redefined so that we can rewind delimited
;; continuations through it

(define (with-input-from-string string thunk)
  (parameterize ((current-input-port (open-input-string string)))
    (thunk)))
