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
Provides:      jami

# Build dependencies.
BuildRequires: cmake
BuildRequires: gcc-c++
BuildRequires: make
BuildRequires: qt5-qttools-devel

# Build and runtime dependencies.
BuildRequires: qrencode-devel
BuildRequires: qt5-qtbase-devel
BuildRequires: qt5-qtdeclarative-devel
BuildRequires: qt5-qtmultimedia-devel
BuildRequires: qt5-qtquickcontrols
BuildRequires: qt5-qtquickcontrols2-devel
BuildRequires: qt5-qtsvg-devel
BuildRequires: qt5-qtwebengine-devel

# Runtime dependencies not automatically registered by RPM.
Requires: qt5-qtquickcontrols
Requires: qt5-qtgraphicaleffects

%description
This package contains the Qt desktop client of Jami. Jami is a free
software for universal communication which respects freedoms and
privacy of its users.

%prep
%setup -n ring-project

%build
cd %{_builddir}/ring-project/client-qt && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=%{_prefix} \
          -DCMAKE_INSTALL_LIBDIR=%{_libdir} \
          -DCMAKE_BUILD_TYPE=Debug \
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
