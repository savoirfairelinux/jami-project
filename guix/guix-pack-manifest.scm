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
             (guix base32)
             (guix packages)
             (guix transformations)
             (guix store)
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

(define %release-version (getenv "RELEASE_VERSION"))

(define %release-file-name (getenv "RELEASE_TARBALL_FILENAME"))

(unless %release-version
  (error "RELEASE_VERSION environment variable is not set"))

(unless %release-file-name
  (error "RELEASE_TARBALL_FILENAME environment variable is not set"))

;;; Add the source tarball to the store and retrieve its hash.  The
;;; hash is useful to turn the origin record into a fixed-output
;;; derivation, which means the Jami packages will only get built once
;;; for a given source tarball.
(define %release-file-hash
  (with-store store
    (let ((source (add-to-store store (basename %release-file-name) #f
                                "sha256" %release-file-name)))
      (bytevector->nix-base32-string (query-path-hash store source)))))

(define %jami-sources/latest
  (origin
    (inherit (@@ (gnu packages jami) %jami-sources))
    (uri %release-file-name)
    (sha256 %release-file-hash)))

(define (with-latest-sources name)
  (options->transformation
   `((with-source . ,(format #f "~a@~a=~a" name
                             %release-version %release-file-name)))))

(define libring/latest ((with-latest-sources "libring") libring))

(define with-libring/latest
  (package-input-rewriting `((,libring . ,libring/latest))))

(define libringclient/latest ((with-latest-sources "libringclient")
                              (with-libring/latest libringclient)))

(define libringclient/latest+libwrap
  (package/inherit libringclient/latest
    (arguments
     (substitute-keyword-arguments (package-arguments libringclient/latest)
       ((#:configure-flags flags ''())
        `(cons "-DENABLE_LIBWRAP=true"
               (delete "-DENABLE_LIBWRAP=false" ,flags)))))))

(define with-libringclient/latest+libwrap
  (package-input-rewriting
   `((,libringclient . ,libringclient/latest+libwrap))))

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
   (with-libringclient/latest+libwrap jami-qt-with-certs)))

(packages->manifest (list jami-qt-with-certs/latest))
