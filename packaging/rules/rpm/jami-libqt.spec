%define name        jami-libqt
%define version     RELEASE_VERSION
%define release     0

# qtwebengine (aka chromium) takes a ton of memory per build process,
# up to 2.3 GiB.  Cap the number of jobs based on the amount of
# available memory to try to guard against OOM build failures.
%define min(a,b) %(echo $(( %1 < %2 ? %1 : %2 )))
%define max(a,b) %(echo $(( %1 > %2 ? %1 : %2 )))

%define cpu_count %max %(nproc) 1
%define available_memory %(free -g | grep -E '^Mem:' | awk '{print $7}')
# Required memory in GiB.
%define max_parallel_builds 4
%define memory_required_per_core 2
%define computed_job_count_ %(echo $(( %available_memory / %memory_required_per_core / %max_parallel_builds )))
%define computed_job_count %max %computed_job_count_ 1
%define job_count %min %cpu_count %computed_job_count

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
echo "Building Qt using %{job_count} parallel jobs"
./configure \
  -opensource \
  -confirm-license \
  -nomake examples \
  -nomake tests \
  -prefix "%{_libdir}/qt-jami"
sed -i 's,bin/python,bin/env python3,g' qtbase/mkspecs/features/uikit/devices.py
# https://bugreports.qt.io/browse/QTBUG-93452 (Qt 5.15)
sed -i 's,#  include <utility>,#  include <utility>\n#  include <limits>,g' qtbase/src/corelib/global/qglobal.h
# Chromium is built using Ninja, which doesn't honor MAKEFLAGS.
make -j%{job_count} V=1 NINJAFLAGS="-j%{job_count}"

%install
make -j%{job_count} INSTALL_ROOT=%{buildroot} V=1 install

%files
%defattr(-,root,root,-)
%{_libdir}/qt-jami
