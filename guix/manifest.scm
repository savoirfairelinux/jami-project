;;; To use with the GNU Guix package manager.
;;; Available at https://guix.gnu.org/.
;;;
;;; Commentary:
;;;
;;; A full-blown development environment that can be used to build the
;;; whole project.  It includes both the GNOME as well as the Qt
;;; libraries, so that both clients can be built.  The sensitive
;;; (i.e., patched) dependencies are consciously omitted from this
;;; list so that the bundled libraries are the ones used, which is
;;; usually what is desired for development purposes.

;;; The make-jami.py script makes use of it to build Jami in a Linux
;;; container with the dependencies below when Guix is detected (and
;;; no /etc/os-release file exists) or when explicitly specified,
;;; e.g.:
;;;
;;; $ ./make-jami.py --distribution=guix --install
;;;
;;; It can also be invoked directly to spawn a development environment, like so:
;;;
;;; $ guix environment --pure --manifest=guix/manifest.scm

(specifications->manifest
 (list
  ;; Minimal requirements of the daemon contrib build system.
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
  "xz"

  ;; For the daemon and its contribs.
  "alsa-lib"
  "autoconf"
  "automake"
  "bash"
  "bzip2"
  "cmake"
  "dbus"
  ;; Bundled because broken with GCC 7 upstream (unmaintained).  When
  ;; attempting to use it, it would cause confusing errors such as
  ;; "ld: ../src/.libs/libring.a(libupnpcontrol_la-upnp_context.o): in
  ;; function `jami::upnp::UPnPContext::updateMappingList(bool)':
  ;; upnp_context.cpp:(.text+0xa4be): undefined reference to
  ;; `std::__cxx11::basic_ostringstream<char, std::char_traits<char>,
  ;; std::allocator<char> >::basic_ostringstream()'
  ;;"dbus-c++"                          ;for dbusxx-xml2cpp
  "diffutils"
  "doxygen"
  "eudev"                               ;udev library
  "expat"
  "findutils"
  "gawk"
  "gettext"
  "gnutls"
  ;;"ffmpeg"                            ;bundled because patched
  "gmp"
  "gsm"
  "gtk-doc"
  "http-parser"
  "jsoncpp"
  "libarchive"
  "libgit2"
  "libnatpmp"
  "libupnp"
  "libsecp256k1"
  "libtool"
  "libva"                               ;vaapi
  "libvdpau"
  "libx264"
  "nasm"
  "nettle"
  "openssl"
  "opus"
  "patch"
  "pcre"
  "perl"
  ;;"pjproject"                         ;bundled because patched
  "pulseaudio"
  "speex"
  "speexdsp"
  "which"
  "yaml-cpp"
  "yasm"

  ;; For libringclient (LRC) and the Qt client.
  "qtbase"
  "qtbase:debug"

  ;; Shared by the GNOME and Qt clients.
  "qrencode"

  ;; Shared by the LRC, GNOME and Qt clients.
  "network-manager"                     ;libnm

  ;; For the GNOME client (client-gnome)
  "adwaita-icon-theme"
  "hicolor-icon-theme"
  "clutter"
  "clutter-gtk"
  "glib:bin"                            ;for glib-compile-resources
  "gtk+"
  "gtk+:debug"
  "libcanberra"
  "libindicator"
  "libnotify"
  "sqlite"
  "webkitgtk"

  ;; For the Qt client.
  "qtsvg"
  "qtsvg:debug"
  "qttools"
  "qtwebengine"
  "qtwebengine:debug"
  "qtwebchannel"
  "qtwebchannel:debug"
  "qtmultimedia"
  "qtmultimedia:debug"
  "qtdeclarative"
  "qtdeclarative:debug"
  "qtgraphicaleffects"
  "qtgraphicaleffects:debug"
  "qtquickcontrols"
  "qtquickcontrols:debug"
  "qtquickcontrols2"
  "qtquickcontrols2:debug"

  ;; For tests and debugging.
  "cppunit"
  "file"
  "gdb"
  "ltrace"
  "strace"))
