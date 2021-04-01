%define name        jami-libqt
%define version     RELEASE_VERSION
%define release     0

Name:          %{name}
Version:       %{version}
Release:       %{release}%{?dist}
Summary:       Library for Jami-qt
Group:         Applications/Internet
Vendor:        Savoir-faire Linux
URL:           https://jami.net/
Source:        jami-qtlib_%{version}.tar.xz

# Build dependencies
#BuildRequires: autoconf

%description
This package contains Qt libraries for Jami.

%prep
%setup -n ring-project

