;;; Copyright (C) 2021 Savoir-faire Linux Inc.
;;;
;;; Author: Maxim Cournoyer <maxim.cournoyer@savoirfairelinux.com>
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;
;;; This GNU Guix manifest is used along the Makefile to build the
;;; latest Jami as a Guix pack.

(use-modules (gnu packages certs)
             (gnu packages jami)
             (guix packages)
             (guix transformations)
             (guix utils))

;;; XXX: Below is a rather strenuous way to specify something that
;;; would have been nicer if it could have been specified via:
;;;
;;; --with-source=libring=$(RELEASE_TARBALL_FILENAME) \
;;; --with-source=libringclient=$(RELEASE_TARBALL_FILENAME) \
;;; --with-source=jami-qt=$(RELEASE_TARBALL_FILENAME) in the Makefile.
;;;
;;; The above doesn't currently rewrite the dependency graph
;;; recursively, hence while it is not sufficient.

(unless (getenv "RELEASE_VERSION")
  (error "RELEASE_VERSION environment variable is not set"))

(unless (getenv "RELEASE_TARBALL_FILENAME")
  (error "RELEASE_TARBALL_FILENAME environment variable is not set"))

(define %jami-sources/latest
  (origin
    (inherit (@@ (gnu packages jami) %jami-sources))
    (uri (getenv "RELEASE_TARBALL_FILENAME"))
    (sha256 #f)))

(define (with-latest-sources name)
  (options->transformation
   `((with-source . ,(format #f "~a@~a=~a" name
                             (getenv "RELEASE_VERSION")
                             (getenv "RELEASE_TARBALL_FILENAME"))))))

(define libring/latest ((with-latest-sources "libring") libring))

(define with-libring/latest
  (package-input-rewriting `((,libring . ,libring/latest))))

(define libringclient/latest ((with-latest-sources "libringclient")
                                (with-libring/latest libringclient)))

(define with-libringclient/latest
  (package-input-rewriting `((,libringclient . ,libringclient/latest))))

;;; Bundling the TLS certificates with Jami enables a fully
;;; functional, configuration-free experience, useful in the context
;;; of Guix packs.
(define jami-qt-with-certs
  (package/inherit jami-qt
    (inputs (cons `("nss-certs" ,nss-certs)
                  (package-inputs jami-qt)))
    (arguments
     (substitute-keyword-arguments (package-arguments jami-qt)
       ((#:phases phases '%standard-phases)
        `(modify-phases ,phases
           (add-after 'qt-wrap 'wrap-ssl-cert-dir
             (lambda* (#:key inputs outputs #:allow-other-keys)
               (let* ((out (assoc-ref outputs "out"))
                      (wrapper (string-append out "/bin/jami-qt"))
                      (nss-certs (assoc-ref inputs "nss-certs")))
                 (substitute* wrapper
                   (("^exec.*" exec-line)
                    (string-append "export SSL_CERT_DIR="
                                   nss-certs
                                   "/etc/ssl/certs\n"
                                   exec-line))))))))))))

(define jami-qt-with-certs/latest
  ((with-latest-sources "jami-qt")
   (with-libringclient/latest jami-qt-with-certs)))

(packages->manifest (list jami-qt-with-certs/latest))
