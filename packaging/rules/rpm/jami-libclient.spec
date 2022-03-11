%define name        jami-libclient
%define version     RELEASE_VERSION
%define release     0
%define __spec_install_pre /bin/true

Name:          %{name}
Version:       %{version}
Release:       %{release}%{?dist}
Summary:       Client library for Jami
Group:         Applications/Internet
License:       GPLv3+
Vendor:        Savoir-faire Linux
URL:           https://jami.net/
Source:        jami_%{version}.tar.gz
Requires:      jami-daemon = %{version}

# Build dependencies
BuildRequires: jami-daemon-devel = %{version}
Requires:      jami-libqt
BuildRequires: make
%if 0%{?fedora} >= 32
BuildRequires: NetworkManager-libnm-devel
BuildRequires: cmake
BuildRequires: gcc-c++
%endif

%description
This package contains the client library of Jami, a free software for
universal communication which respects freedoms and privacy of its
users.

%prep
%setup -n jami-project

%build
# Qt-related variables
cd %{_builddir}/jami-project/lrc && \
    mkdir build && cd build && \
    cmake -DRING_BUILD_DIR=%{_builddir}/jami-project/daemon/src \
          -DENABLE_LIBWRAP=true \
          -DCMAKE_INSTALL_PREFIX=%{_prefix} \
          -DCMAKE_INSTALL_LIBDIR=%{_libdir} \
          -DCMAKE_BUILD_TYPE=Release \
          ..
make -C %{_builddir}/jami-project/lrc/build %{_smp_mflags} V=1

%install
DESTDIR=%{buildroot} make -C lrc/build install

%files
%defattr(-,root,root,-)
%{_libdir}/libringclient.so.1.0.0
%{_datadir}/libringclient

%package devel
Summary: Development files of the Jami client library

%description devel
This package contains the header files and the unversioned shared
library for developing with the Jami client library.

%files devel
%{_includedir}/libringclient
%{_libdir}/cmake/LibRingClient
# The following is a symbolic link.
%{_libdir}/libringclient.so

%post
/sbin/ldconfig

%postun
/sbin/ldconfig
