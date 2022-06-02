# Made into a transitional package on 2022-06-21, after libjamiclient
# was merged into src/libclient under jami-client-qt.git, to provide
# an upgrade path to existing users.  Feel free to remove this package
# later into the future, some time after 2023-06-21 perhaps.

%define name        jami-libclient
%define version     RELEASE_VERSION
%define release     0

Name:          %{name}
Version:       %{version}
Release:       %{release}%{?dist}
Summary:       Transitional package for Jami; can be safely removed
Group:         Applications/Internet
License:       GPLv3+
Vendor:        Savoir-faire Linux
URL:           https://jami.net/
Source:        jami_%{version}.tar.gz

%description
This is a transitional package. Jami libclient has been merged into
the jami-qt client code-base, and this package can be safely removed.
