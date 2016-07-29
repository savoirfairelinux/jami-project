%define name        ring
%define version     RELEASE_VERSION
%define release     0

Name:          %{name}
Version:       %{version}
Release:       %{release}%{?dist}
Summary:       Free software for distributed and secured communication.
Group:         Applications/Internet
License:       GPLv3
URL:           https://ring.cx/
Source:        ring_%{version}.tar.gz
Requires:      ring-daemon = %{version}

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
BuildRequires: gsm-devel
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
%setup -n ring-project

%build
###########################
## Ring Daemon configure ##
###########################
mkdir -p daemon/contrib/native
cd %{_builddir}/ring-project/daemon/contrib/native && \
    ../bootstrap \
        --no-checksums \
	    --disable-ogg \
        --disable-flac \
        --disable-vorbis \
        --disable-vorbisenc \
        --disable-speex \
        --disable-sndfile \
        --disable-gsm \
        --disable-speexdsp && \
    make list && \
    make -j1 V=1

cd %{_builddir}/ring-project/daemon && \
    ./autogen.sh && \
    ./configure \
        --prefix=%{_prefix} \
        --libdir=%{_libdir}

#############################
## libringclient configure ##
#############################
cd %{_builddir}/ring-project/lrc && \
    mkdir build && \
    cd build && \
    cmake \
        -DRING_BUILD_DIR=%{_builddir}/ring-project/daemon/src \
        -DCMAKE_INSTALL_PREFIX=%{_prefix} \
        -DCMAKE_INSTALL_LIBDIR=%{_libdir} \
        -DCMAKE_BUILD_TYPE=Debug \
    ..

############################
## gnome client configure ##
############################
cd %{_builddir}/ring-project/client-gnome && \
    mkdir build && \
    cd build && \
    cmake \
        -DCMAKE_INSTALL_PREFIX=%{_prefix} \
        -DCMAKE_INSTALL_LIBDIR=%{_libdir} \
        -DLibRingClient_PROJECT_DIR=%{_builddir}/ring-project/lrc \
        ..

#######################
## Ring Daemon build ##
#######################
make -C %{_builddir}/ring-project/daemon -j4 V=1
pod2man %{_builddir}/ring-project/daemon/man/dring.pod > %{_builddir}/ring-project/daemon/dring.1

#########################
## libringclient build ##
#########################
make -C %{_builddir}/ring-project/lrc/build -j4 V=1

########################
## gnome client build ##
########################
make -C %{_builddir}/ring-project/client-gnome/build LDFLAGS="-lpthread" -j4 V=1


%install
#########################
## Ring Daemon install ##
#########################
DESTDIR=%{buildroot} make -C daemon install
cp %{_builddir}/ring-project/daemon/dring.1 %{buildroot}/%{_mandir}/man1/dring.1
rm -rfv %{buildroot}/%{_prefix}/include
rm -rfv %{buildroot}/%{_libdir}/*.a
rm -rfv %{buildroot}/%{_libdir}/*.la

###########################
## libringclient install ##
###########################
DESTDIR=%{buildroot} make -C lrc/build install
rm -rfv %{buildroot}/%{_prefix}/include

# This is a symlink, should be in -dev package
rm -v %{buildroot}/%{_libdir}/libringclient.so

# cmake files
rm -rfv %{buildroot}/%{_libdir}/cmake

##########################
## gnome client install ##
##########################
DESTDIR=%{buildroot} make -C client-gnome/build install

%files
%defattr(-,root,root,-)
%{_bindir}/ring.cx
%{_bindir}/gnome-ring
%{_libdir}/libringclient*.so*
%{_datadir}/glib-2.0/schemas/cx.ring.RingGnome.gschema.xml
%{_datadir}/applications/gnome-ring.desktop
%{_datadir}/gnome-ring/gnome-ring.desktop
%{_datadir}/icons/hicolor/scalable/apps/ring.svg
%{_datadir}/appdata/gnome-ring.appdata.xml
%{_datadir}/libringclient/*
%{_datadir}/locale/*
%doc %{_mandir}/man1/dring*

%files daemon
%defattr(-,root,root,-)
%{_libdir}/ring
%{_datadir}/ring/ringtones
%{_datadir}/dbus-1/services/*
%{_datadir}/dbus-1/interfaces/*

%changelog
