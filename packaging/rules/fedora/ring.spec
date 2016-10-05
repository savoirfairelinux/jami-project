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
Obsoletes:     ring-gnome

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
BuildRequires: libXfixes-devel
BuildRequires: uuid-devel
BuildRequires: gnutls-devel
BuildRequires: nettle-devel
BuildRequires: opus-devel
BuildRequires: jsoncpp-devel
BuildRequires: libnatpmp-devel
BuildRequires: gsm-devel
BuildRequires: libupnp-devel
BuildRequires: gcc-c++
BuildRequires: qt5-qtbase-devel
BuildRequires: gnome-icon-theme-symbolic
BuildRequires: clutter-gtk-devel
BuildRequires: clutter-devel
BuildRequires: glib2-devel
BuildRequires: gtk3-devel
BuildRequires: evolution-data-server-devel
BuildRequires: libnotify-devel
BuildRequires: qt5-qttools-devel
BuildRequires: qrencode-devel
BuildRequires: libappindicator-gtk3-devel
BuildRequires: NetworkManager-glib-devel
BuildRequires: libva-devel

%description
Ring is free software for universal communication which respects freedoms
and privacy of its users.
.
This package contains the desktop client: gnome-ring.

%package daemon
Summary: Free software for distributed and secured communication - daemon

%description daemon
Ring is free software for universal communication which respects freedoms
and privacy of its users.
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
        --disable-speexdsp \
        --disable-natpmp && \
    make list && \
    make fetch && \
    make -j1 V=1

cd %{_builddir}/ring-project/daemon && \
    ./autogen.sh && \
    ./configure \
        --prefix=%{_prefix} \
        --libdir=%{_libdir} \
        --disable-shared

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
        -DGSETTINGS_LOCALCOMPILE=OFF \
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
%{_libdir}/ring/dring
%{_datadir}/ring/ringtones
%{_datadir}/dbus-1/services/*
%{_datadir}/dbus-1/interfaces/*

%post -p /sbin/ldconfig

%postun
-p /sbin/ldconfig

#for < f24 we have to update the schema explicitly
%if 0%{?fedora} < 24
    if [ $1 -eq 0 ] ; then
        /usr/bin/glib-compile-schemas %{_datadir}/glib-2.0/schemas &> /dev/null || :
    fi
%endif

%posttrans
#for < f24 we have to update the schema explicitly
%if 0%{?fedora} < 24
    /usr/bin/glib-compile-schemas %{_datadir}/glib-2.0/schemas &> /dev/null || :
%endif


%changelog
