%define name        jami-libqt
%define version     RELEASE_VERSION
%define release     0

Name:          %{name}
Version:       %{version}
Release:       %{release}%{?dist}
Summary:       Library for Jami-qt
Group:         Applications/Internet
License:       GPLv3+
Vendor:        Savoir-faire Linux
URL:           https://jami.net/
Source:        jami-qtlib_%{version}.tar.xz

# Build dependencies
BuildRequires: autoconf
BuildRequires: make
# QtWebEngine
BuildRequires: bison
BuildRequires: gperf
BuildRequires: flex
%if %{defined suse_version}
BuildRequires: python-xml
BuildRequires: mozilla-nss-devel
%endif

%description
This package contains Qt libraries for Jami.

%prep
%setup -n qt-everywhere-src-%{version}

%build
	./configure \
		-opensource \
		-confirm-license \
		-nomake examples \
		-nomake tests \
		-prefix "%{_libdir}/qt-jami"
	sed -i 's,bin/python,bin/env python3,g' qtbase/mkspecs/features/uikit/devices.py
	make -j8 V=1

%install
make -j8 INSTALL_ROOT=%{buildroot} V=1 install

%files
%defattr(-,root,root,-)
%{_libdir}/qt-jami