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

(define-module (guile-wm module simple-focus)
  #:use-module (xcb event-loop)
  #:use-module (xcb xml)
  #:use-module (xcb xml xproto)
  #:use-module (guile-wm shared)
  #:use-module (guile-wm icccm)
  #:use-module (guile-wm color)
  #:use-module (guile-wm focus)
  #:use-module (guile-wm reparent))

(define simple-focus-color-val 'white)
(define simple-unfocus-color-val 'black)

(define (is-window? win)
  (not (memv (xid->integer win) (xenum-values input-focus))))

(define-public simple-focus-color
  (make-procedure-with-setter
   (lambda () simple-focus-color-val)
   (lambda (new-color)
     (set! simple-focus-color-val new-color)
     (with-replies ((input-focus get-input-focus))
       (define old-focus (xref input-focus 'focus))
       (if (is-window? old-focus)
        (run-wm-hook focus-change old-focus old-focus))))))

(define-public simple-unfocus-color
  (make-procedure-with-setter
   (lambda () simple-unfocus-color-val)
   (lambda (new-color) (set! simple-unfocus-color-val new-color))))

(define (unfocus-window! win)
  (define cmap (xref (current-screen) 'default-colormap))
  (change-window-attributes (window-parent win)
    #:border-pixel (pixel-for-color cmap simple-unfocus-color-val)))

(define (simple-focus-change old new)
  (define cmap (xref (current-screen) 'default-colormap))
  (if (and old (or (reparented? old) (top-level-window? old)))
      (unfocus-window! old))
  (if (and current-focus (is-window? current-focus))
      (unfocus-window! current-focus))
  (change-window-attributes (window-parent new)
    #:border-pixel (pixel-for-color cmap simple-focus-color-val))
  (set! current-focus new))

(wm-init
 (lambda ()
   (add-wm-hook! focus-change simple-focus-change)))
