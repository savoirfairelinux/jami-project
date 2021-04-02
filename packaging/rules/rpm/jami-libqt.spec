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
#BuildRequires: autoconf

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
    make -j8 V=1

%install
    make -j8 V=1 install


%files
%defattr(-,root,root,-)
%{_libdir}/qt-jami