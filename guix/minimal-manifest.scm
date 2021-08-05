;;; To use with the GNU Guix package manager.
;;; Available at https://guix.gnu.org/.
;;;
;;; Commentary:
;;;
;;; This Guix manifest can be used to create an environment that
;;; satisfies the minimal requirements of the the contrib build system
;;; of the daemon.  For example, it is used by the CI to build the
;;; source release tarball in a controlled environment.

(specifications->manifest
 (list
  "coreutils"
  "gcc-toolchain"
  "git-minimal"
  "grep"
  "gzip"
  "make"
  "nss-certs"
  "pkg-config"
  "python"
  "sed"
  "tar"
  "util-linux"
  "wget"
  "xz"))
