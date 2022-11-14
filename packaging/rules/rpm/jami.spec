%define name        jami
%define version     RELEASE_VERSION
%define release     0

Name:          %{name}
Version:       %{version}
Release:       %{release}%{?dist}
Summary:       Qt client for Jami
Group:         Applications/Internet
License:       GPLv3+
Vendor:        Savoir-faire Linux
URL:           https://jami.net/
Source:        jami_%{version}.tar.gz
Requires:      jami-daemon = %{version}
Requires:      jami-libqt
Provides:      jami-qt = %{version}
Obsoletes:     jami-qt < 20221010.1109.641d67d-2
Obsoletes:     jami-libclient <= 20220516.0214.9b42ad3-1

# Build dependencies.
%if 0%{?fedora} >= 32
BuildRequires: cmake
BuildRequires: gcc-c++
%endif
BuildRequires: make

# For generating resources.qrc in build time.
BuildRequires: python3

# Build and runtime dependencies.
BuildRequires: qrencode-devel

%description
This package contains the Qt desktop client of Jami. Jami is a free
software for universal communication which respects freedoms and
privacy of its users.

%prep
%setup -n jami-project

%build
# Configure and build bundled ffmpeg (for libavutil/avframe).
mkdir -p %{_builddir}/jami-project/daemon/contrib/native
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
    make %{_smp_mflags} V=1 .ffmpeg
# Qt-related variables
cd %{_builddir}/jami-project/client-qt && \
    mkdir build && cd build && \
    cmake -DENABLE_LIBWRAP=true \
          -DLIBJAMI_BUILD_DIR=%{_builddir}/jami-project/daemon/src \
          -DCMAKE_INSTALL_PREFIX=%{_prefix} \
          -DCMAKE_INSTALL_LIBDIR=%{_libdir} \
          -DCMAKE_BUILD_TYPE=Release \
          ..
make -C %{_builddir}/jami-project/client-qt/build %{_smp_mflags} V=1

%install
DESTDIR=%{buildroot} make -C %{_builddir}/jami-project/client-qt/build install

%files
%defattr(-,root,root,-)
%{_bindir}/jami
%{_datadir}/applications/jami.desktop
%{_datadir}/jami/jami.desktop
%{_datadir}/icons/hicolor/scalable/apps/jami.svg
%{_datadir}/icons/hicolor/48x48/apps/jami.png
%{_datadir}/pixmaps/jami.xpm
%{_datadir}/metainfo/jami.appdata.xml
%{_datadir}/jami/translations/*
%doc %{_mandir}/man1/jami*