%define name        jami-qt
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
Requires:      jami-libclient = %{version}
%if 0%{?fedora} < 35
Requires:      jami-libqt
%endif
%if 0%{?fedora} >= 35
BuildRequires: qt6-qttools-devel
BuildRequires: qt6-qtbase-devel
BuildRequires: qt6-qtdeclarative-devel
BuildRequires: qt6-qtmultimedia-devel
BuildRequires: qt6-qtquickcontrols2
BuildRequires: qt6-qtquickcontrols2-devel
BuildRequires: qt6-qtsvg-devel
BuildRequires: qt6-qtwebengine-devel
# Runtime dependencies not automatically registered by RPM.
Requires: qt6-qtquickcontrols2
%endif
Provides:      jami
Obsoletes:     jami < %{version}-%{release}

# Build dependencies.
BuildRequires: cmake
BuildRequires: gcc-c++
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
%setup -n ring-project

%build

# Qt-related variables
cd %{_builddir}/ring-project/client-qt && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=%{_prefix} \
          -DCMAKE_INSTALL_LIBDIR=%{_libdir} \
          -DCMAKE_BUILD_TYPE=Release \
          ..

make -C %{_builddir}/ring-project/client-qt/build %{_smp_mflags} V=1

%install
DESTDIR=%{buildroot} make -C %{_builddir}/ring-project/client-qt/build install

%files
%defattr(-,root,root,-)
%{_bindir}/jami
%{_bindir}/jami-qt
%{_datadir}/applications/jami-qt.desktop
%{_datadir}/jami-qt/jami-qt.desktop
%{_datadir}/icons/hicolor/scalable/apps/jami.svg
%{_datadir}/icons/hicolor/48x48/apps/jami.png
%{_datadir}/pixmaps/jami.xpm
%{_datadir}/metainfo/jami-qt.appdata.xml
%{_datadir}/ring/translations/*
