%define name        jami-daemon
%define version     RELEASE_VERSION
%define release     0

Name:          %{name}
Version:       %{version}
Release:       %{release}%{?dist}
Summary:       Daemon component of Jami
Group:         Applications/Internet
License:       GPLv3+
Vendor:        Savoir-faire Linux
URL:           https://jami.net/
Source:        jami_%{version}.tar.gz
Requires:      jami-daemon = %{version}

# Build dependencies
BuildRequires: autoconf
BuildRequires: automake
BuildRequires: gettext-devel
BuildRequires: libtool
BuildRequires: make
BuildRequires: which
BuildRequires: yasm

# Build and runtime dependencies.  Requires directives are
# automatically made to linked shared libraries via RPM, so there's no
# need to explicitly relist them.
%if 0%{?fedora} >= 32
BuildRequires: NetworkManager-libnm-devel
BuildRequires: cmake
BuildRequires: gcc-c++
BuildRequires: dbus-devel
BuildRequires: expat-devel
BuildRequires: opus-devel
BuildRequires: pulseaudio-libs-devel
%endif
%if %{defined suse_version}
BuildRequires: libdbus-c++-devel
BuildRequires: libexpat-devel
BuildRequires: libopus-devel
BuildRequires: libpulse-devel
%endif
BuildRequires: gnutls-devel
BuildRequires: alsa-lib-devel
BuildRequires: jsoncpp-devel
BuildRequires: libXext-devel
BuildRequires: libXfixes-devel
BuildRequires: libuuid-devel
BuildRequires: libva-devel
BuildRequires: libvdpau-devel
BuildRequires: pcre-devel
BuildRequires: uuid-devel
BuildRequires: yaml-cpp-devel

%description
This package contains the daemon of Jami, a free software for
universal communication which respects the freedoms and privacy of its
users.

%prep
%setup -n jami-project

%build
CFLAGS="${CFLAGS} -fno-lto"
CXXFLAGS="${CXXFLAGS} -fno-lto"
# Configure the Jami bundled libraries (ffmpeg & pjproject).
mkdir -p daemon/contrib/native
cd %{_builddir}/jami-project/daemon/contrib/native && \
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
    make %{_smp_mflags} V=1 && \
    make %{_smp_mflags} V=1 .ffmpeg
# Configure the daemon.
cd %{_builddir}/jami-project/daemon && \
    ./autogen.sh && \
    ./configure \
        --prefix=%{_prefix} \
        --libdir=%{_libdir}
# Build the daemon.
make -C %{_builddir}/jami-project/daemon %{_smp_mflags} V=1
pod2man %{_builddir}/jami-project/daemon/man/jamid.pod \
        > %{_builddir}/jami-project/daemon/jamid.1

%install
DESTDIR=%{buildroot} make -C daemon install
cp %{_builddir}/jami-project/daemon/jamid.1 \
   %{buildroot}/%{_mandir}/man1/jamid.1
rm -rfv %{buildroot}/%{_libdir}/*.a
rm -rfv %{buildroot}/%{_libdir}/*.la

%files
%defattr(-,root,root,-)
%{_libdir}/libring.so*
# XXX: Use %%{_libexecdir}/jamid after there's no more OpenSUSE Leap
# < 16 (see https://en.opensuse.org/openSUSE:Specfile_guidelines).
/usr/libexec/jamid
%{_datadir}/jami/ringtones
%{_datadir}/dbus-1/services/*
%{_datadir}/dbus-1/interfaces/*
%doc %{_mandir}/man1/jamid*

%package devel
Summary: Development files of the Jami daemon

%description devel
This package contains the header files for using the Jami daemon as a library.

%files devel
%{_includedir}/jami

%post
/sbin/ldconfig

%postun
/sbin/ldconfig
