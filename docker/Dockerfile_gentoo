FROM gentoo/stage3-amd64:latest

RUN emerge-webrsync

ADD scripts/gentoo/portage/ /etc/portage/

# profile with gnome and systemd configuration
RUN eselect profile set 5 && \
	emerge -uDN world

RUN eselect news read

RUN emerge layman && echo "source /var/lib/layman/make.conf" >> /etc/portage/make.conf

ADD scripts/build-package-gentoo.sh /opt/build-package-gentoo.sh

CMD /bin/bash /opt/build-package-gentoo.sh

