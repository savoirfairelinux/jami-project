# Made into a transitional package on 2022-10-12, after the 'jami-qt'
# to 'jami' rename, to provide an upgrade path to existing users.
# Feel free to remove this package later into the future, some time
# after 2023-10-12 perhaps.

%define name        jami-qt
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
Requires:      jami

%description
This is a transitional package. The Jami Qt client is now packaged
under the name 'jami', and this package can be safely removed.

# Required, otherwise no rpm is generated.
%files
