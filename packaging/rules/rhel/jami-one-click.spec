%define name        jami-all
%define version     RELEASE_VERSION
%define release     0
%define postinst    jami-all.postinst

Name:          %{name}
Version:       %{version}
Release:       %{release}%{?dist}
Summary:       Free software for distributed and secured communication.
Group:         Applications/Internet
License:       GPLv3+
URL:           https://jami.net/
Source:        jami_%{version}.tar.gz
#Requires:      jami-daemon = %{version}
Obsoletes:     ring ring-daemon
Provides:      ring
Conflicts:     ring ring-daemon


BuildRequires: make
BuildRequires: autoconf
BuildRequires: automake
BuildRequires: cmake
BuildRequires: pulseaudio-libs-devel
BuildRequires: libcanberra-devel
BuildRequires: libtool
BuildRequires: expat-devel
BuildRequires: pcre-devel
BuildRequires: boost-devel
BuildRequires: dbus-devel
BuildRequires: libXext-devel
BuildRequires: chrpath
BuildRequires: check
BuildRequires: gettext-devel
BuildRequires: gcc-c++
BuildRequires: which
BuildRequires: alsa-lib-devel
BuildRequires: systemd-devel
BuildRequires: libuuid-devel
BuildRequires: libXfixes-devel
BuildRequires: gnutls-devel
BuildRequires: nettle-devel
#BuildRequires: jsoncpp-devel
#BuildRequires: json-devel
BuildRequires: gcc-c++
BuildRequires: glib2-devel
BuildRequires: gtk3-devel
BuildRequires: libva-devel
BuildRequires: webkitgtk4-devel
BuildRequires: qt5-devel
BuildRequires: clutter
BuildRequires: clutter-devel
BuildRequires: clutter-gtk-devel
BuildRequires: qrencode-devel
BuildRequires: yasm
BuildRequires: opus
BuildRequires: opus-devel
BuildRequires: libvdpau-devel
BuildRequires: libvdpau
BuildRequires: speexdsp
BuildRequires: speexdsp-devel
BuildRequires: cppunit-devel
BuildRequires: cppunit
BuildRequires: dbus-c++


%description
Jami is free software for universal communication which respects freedoms
and privacy of its users.
.
This package contains the desktop client: jami-gnome.

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
    make -j4 V=1 && \
    make -j4 V=1 .ffmpeg

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
ln -sf %{_bindir}/jami %{buildroot}/%{_bindir}/ring.cx

##########################
## post install script  ##
##########################
#mkdir -p %{buildroot}/opt/repo-package/
cp %{_builddir}/ring-project/packaging/rules/rhel/%{postinst} %{buildroot}/%{_bindir}
chmod a+x %{buildroot}/%{_bindir}/%{postinst}

%files 
%{_bindir}/jami
%{_bindir}/ring.cx
%{_bindir}/jami-gnome
%{_libdir}/libringclient*.so*
%{_datadir}/glib-2.0/schemas/net.jami.Jami.gschema.xml
%{_datadir}/applications/jami-gnome.desktop
%{_datadir}/jami-gnome/jami-gnome.desktop
%{_datadir}/icons/hicolor/scalable/apps/jami.svg
%{_datadir}/metainfo/jami-gnome.appdata.xml
%{_datadir}/libringclient/*
%{_datadir}/locale/*
%{_datadir}/sounds/jami-gnome/*
%doc %{_mandir}/man1/dring*
%{_libdir}/ring/dring
%{_datadir}/ring/ringtones
%{_datadir}/dbus-1/services/*
%{_datadir}/dbus-1/interfaces/*
%{_bindir}/%{postinst}


%post
/sbin/ldconfig
/bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null || :
if [ $1 == 1 ];then
   %{_bindir}/%{postinst}
fi

%postun
/sbin/ldconfig

#for < f24 we have to update the schema explicitly
%if 0%{?fedora} < 24
    if [ $1 -eq 0 ] ; then
        /usr/bin/glib-compile-schemas %{_datadir}/glib-2.0/schemas &> /dev/null || :
    fi
%endif

if [ $1 -eq 0 ] ; then
    /bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null
    /usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :
fi

%posttrans
#for < f24 we have to update the schema explicitly
%if 0%{?fedora} < 24
    /usr/bin/glib-compile-schemas %{_datadir}/glib-2.0/schemas &> /dev/null || :
%endif

/usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :

%changelog
