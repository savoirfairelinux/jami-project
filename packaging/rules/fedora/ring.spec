%define name        ring
%define version     RELEASE_VERSION
%define release     1

Name:          %{name}
Version:       %{version}
Release:       %{release}%{?dist}
Summary:       Free software for distributed and secured communication.
Group:         Applications/Internet
License:       GPLv3
URL:           http://ring.cx/
Source:        daemon

BuildRequires: make
BuildRequires: autoconf
BuildRequires: automake
BuildRequires: cmake
BuildRequires: pulseaudio-libs-devel
BuildRequires: libsamplerate-devel
BuildRequires: libtool
BuildRequires: dbus-devel
BuildRequires: expat-devel
BuildRequires: pcre-devel
BuildRequires: yaml-cpp-devel
BuildRequires: boost-devel
BuildRequires: dbus-c++-devel
BuildRequires: dbus-devel
BuildRequires: libsndfile-devel
BuildRequires: libXext-devel
BuildRequires: yasm
BuildRequires: git
BuildRequires: speex-devel
BuildRequires: chrpath
BuildRequires: check
BuildRequires: astyle
BuildRequires: uuid-c++-devel
BuildRequires: gettext-devel
BuildRequires: gcc-c++
BuildRequires: which
BuildRequires: alsa-lib-devel
BuildRequires: systemd-devel
BuildRequires: libuuid-devel
BuildRequires: uuid-devel
BuildRequires: gnutls-devel
BuildRequires: nettle-devel
BuildRequires: opus-devel
BuildRequires: jsoncpp-devel
BuildRequires: libnatpmp-devel
BuildRequires: libupnp-devel
BuildRequires: autoconf
BuildRequires: automake
BuildRequires: libtool
BuildRequires: dbus-devel
BuildRequires: pcre-devel
BuildRequires: yaml-cpp-devel
BuildRequires: gcc-c++
BuildRequires: boost-devel
BuildRequires: dbus-c++-devel
BuildRequires: dbus-devel
BuildRequires: libupnp-devel
BuildRequires: qt5-qtbase-devel
BuildRequires: gnome-icon-theme-symbolic
BuildRequires: chrpath
BuildRequires: check
BuildRequires: astyle
BuildRequires: gnutls-devel
BuildRequires: yasm
BuildRequires: git
BuildRequires: cmake
BuildRequires: clutter-gtk-devel
BuildRequires: clutter-devel
BuildRequires: glib2-devel
BuildRequires: gtk3-devel
BuildRequires: evolution-data-server-devel
BuildRequires: libnotify-devel
BuildRequires: qt5-qttools-devel
BuildRequires: gettext
BuildRequires: qrencode-devel
BuildRequires: libappindicator-gtk3-devel
BuildRequires: NetworkManager-glib-devel

%description
Ring (ring.cx) is a secure and distributed voice, video and chat communication
platform that requires no centralized server and leaves the power of privacy
in the hands of the user.
.
This package contains the desktop client: gnome-ring.

%package daemon
Summary: Free software for distributed and secured communication - daemon

%description daemon
Ring (ring.cx) is a secure and distributed voice, video and chat communication
platform that requires no centralized server and leaves the power of privacy
in the hands of the user.
.
This package contains the Ring daemon: dring.

%prep
%setup -q
git init
git remote add origin https://gerrit-ring.savoirfairelinux.com/ring-daemon
git fetch --all
git checkout %{daemon_tag} -f
git config user.name "joulupukki"
git config user.email "joulupukki@localhost"
git merge origin/packaging --no-commit
git reset HEAD
# Apply all patches
for patch_file in $(cat debian/patches/series | grep -v "^#")
do
%{__patch} -p1 < debian/patches/$patch_file
done


%build
echo "build"
pwd 
ls

%install
echo "install"
pwd
ls

%files
%defattr(-,root,root,-)

%files daemon
%defattr(-,root,root,-)

%changelog
