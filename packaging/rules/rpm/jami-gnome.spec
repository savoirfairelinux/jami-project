%define name        jami-gnome
%define version     RELEASE_VERSION
%define release     0

Name:          %{name}
Version:       %{version}
Release:       %{release}%{?dist}
Summary:       GNOME desktop client for Jami
Group:         Applications/Internet
License:       GPLv3+
Vendor:        Savoir-faire Linux
URL:           https://jami.net/
Source:        jami_%{version}.tar.gz
Requires:      jami-libclient = %{version}

# Build dependencies.
BuildRequires: cmake
BuildRequires: gcc
BuildRequires: make
BuildRequires: gettext-devel

# Build and runtime dependencies.
BuildRequires: glib2-devel
%if 0%{?fedora} >= 32
BuildRequires: dbus-devel
BuildRequires: libnotify-devel
BuildRequires: libappindicator-gtk3-devel
BuildRequires: webkitgtk4-devel
%endif
%if %{defined suse_version}
BuildRequires: libdbus-c++-devel
BuildRequires: libappindicator-devel
BuildRequires: webkit2gtk3-devel
%endif
BuildRequires: clutter-devel
BuildRequires: clutter-gtk-devel
BuildRequires: gtk3-devel
BuildRequires: libcanberra-devel
BuildRequires: qrencode-devel

%description
This package contains the GNOME desktop client of Jami. Jami is a free
software for universal communication which respects freedoms and
privacy of its users.

%prep %setup -n ring-project

%build
cd %{_builddir}/ring-project/client-gnome && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=%{_prefix} \
          -DCMAKE_INSTALL_LIBDIR=%{_libdir} \
          -DCMAKE_BUILD_TYPE=Debug \
          -DGSETTINGS_LOCALCOMPILE=OFF \
          ..

make -C %{_builddir}/ring-project/client-gnome/build \
    LDFLAGS="-lpthread" %{_smp_mflags} V=1

%install
DESTDIR=%{buildroot} make -C %{_builddir}/ring-project/client-gnome/build install
# Only keep /bin/jami-gnome for the GNOME client.
rm -rfv %{buildroot}/%{_bindir}/jami
rm -rfv %{buildroot}/%{_bindir}/ring.cx

%files
%defattr(-,root,root,-)
%{_bindir}/jami-gnome
%{_datadir}/applications/jami-gnome.desktop
%{_datadir}/glib-2.0/schemas/net.jami.Jami.gschema.xml
%{_datadir}/icons/hicolor/scalable/apps/jami.svg
%{_datadir}/jami-gnome
%{_datadir}/locale/*
%{_datadir}/metainfo/jami-gnome.appdata.xml
%{_datadir}/sounds/jami-gnome
