%define name        jami-libqt
%define version     RELEASE_VERSION
%define release     3

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

%global gst 0.10
%if 0%{?fedora} || 0%{?rhel} > 7
%global gst 1.0
%endif

# Build dependencies
BuildRequires: autoconf
BuildRequires: make
# QtWebEngine
BuildRequires: bison
BuildRequires: gperf
BuildRequires: flex
BuildRequires: vulkan-devel
%if %{defined suse_version}
BuildRequires: ffmpeg-devel
BuildRequires: ffmpeg
BuildRequires: python-xml
BuildRequires: mozilla-nss-devel
%else
BuildRequires: pkgconfig(gstreamer-%{gst})
BuildRequires: pkgconfig(gstreamer-app-%{gst})
BuildRequires: pkgconfig(gstreamer-audio-%{gst})
BuildRequires: pkgconfig(gstreamer-base-%{gst})
BuildRequires: pkgconfig(gstreamer-pbutils-%{gst})
BuildRequires: pkgconfig(gstreamer-plugins-bad-%{gst})
BuildRequires: pkgconfig(gstreamer-video-%{gst})
%endif

%description
This package contains Qt libraries for Jami.

%prep
%setup -n qt-everywhere-src-%{version}

%build
echo "Building Qt using %{job_count} parallel jobs"
# Qt 6.2 (https://wiki.linuxfromscratch.org/blfs/ticket/14729)
sed -i 's,default=False,default=True,g' qtwebengine/src/3rdparty/chromium/third_party/catapult/tracing/tracing_build/generate_about_tracing_contents.py
# https://bugs.gentoo.org/768261 (Qt 5.15)
sed -i 's,#include "absl/base/internal/spinlock.h"1,#include "absl/base/internal/spinlock.h"1\n#include <limits>,g' qtwebengine/src/3rdparty/chromium/third_party/abseil-cpp/absl/synchronization/internal/graphcycles.cc
sed -i 's,#include <stdint.h>,#include <stdint.h>\n#include <limits>,g' qtwebengine/src/3rdparty/chromium/third_party/perfetto/src/trace_processor/containers/string_pool.h
# else, break build for fedora 35
sed -i 's/static const unsigned kSigStackSize = std::max(16384, SIGSTKSZ);/static const size_t kSigStackSize = std::max(size_t(16384), size_t(SIGSTKSZ));/g' qtwebengine/src/3rdparty/chromium/third_party/breakpad/breakpad/src/client/linux/handler/exception_handler.cc
# https://bugreports.qt.io/browse/QTBUG-93452 (Qt 5.15)
sed -i 's,#  include <utility>,#  include <utility>\n#  include <limits>,g' qtbase/src/corelib/global/qglobal.h
sed -i 's,#include <string.h>,#include <string.h>\n#include <limits>,g' qtbase/src/corelib/global/qendian.h
cat qtbase/src/corelib/global/qendian.h
sed -i 's,#include <string.h>,#include <string.h>\n#include <limits>,g' qtbase/src/corelib/global/qfloat16.h
sed -i 's,#include <QtCore/qbytearray.h>,#include <QtCore/qbytearray.h>\n#include <limits>,g' qtbase/src/corelib/text/qbytearraymatcher.h
# Apply patches (Fix in Qt 6.2.4)
ls /root/rpmbuild/SOURCES/
pwd
patch -flp1 < /root/rpmbuild/SOURCES/patches/0001-qtbug-102017-sporadic-binding-crash.patch
patch -flp1 < /root/rpmbuild/SOURCES/patches/0002-qtbug-101201-fatal-errror-getcurrenkeyboard.patch
# recent gcc version do not like lto from qt
CXXFLAGS="${CXXFLAGS} -fno-lto" CFLAGS="${CFLAGS} -fno-lto" ./configure \
  -opensource \
  -confirm-license \
  -nomake examples \
  -nomake tests \
  -prefix "%{_libdir}/qt-jami"
sed -i 's,bin/python,bin/env python3,g' qtbase/mkspecs/features/uikit/devices.py
# Chromium is built using Ninja, which doesn't honor MAKEFLAGS.
cmake --build . --parallel

%install
cmake --install . --prefix %{buildroot}/${QT_JAMI_PREFIX}

%files
%defattr(-,root,root,-)
%{_libdir}/qt-jami
