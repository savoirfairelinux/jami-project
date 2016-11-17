FROM ubuntu:16.04

ENV LANG en_US.utf8
ENV LC_ALL en_US.utf8
ENV HOME /home/builder
ENV SSH_AUTH_SOCK /home/builder/.sockets/ssh

RUN apt-get update && apt-get install -y --no-install-recommends \
	asciidoc \
	autogen \
	automake \
	autoconf \
	autopoint \
	ca-certificates \
	cmake \
	bc \
	bison \
	build-essential \
	bzip2 \
	doxygen \
	git \
	gradle \
	lib32stdc++6 \
	lib32z1 \
	libtool \
	m4 \
	openjdk-8-jdk \
	pkg-config \
	python-software-properties \
	ssh \
	swig \
	software-properties-common \
	unzip \
	wget \
	yasm \
	zip \
	&& locale-gen $LANG $LC_ALL && update-locale $LANG $LC_ALL


ENV ANDROID_DEPS=platform-tools,\
build-tools-24.0.2,\
android-24,\
extra-android-support,\
extra-android-m2repository,\
extra-google-m2repository

# Android Linux SDK
# See http://developer.android.com/sdk/index.html
RUN wget -O /tmp/android-sdk.tgz http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz && \
	tar -C /opt/ -zxf /tmp/android-sdk.tgz && \
	rm -f /tmp/android-sdk.tgz && \
	chown -R root:root /opt/android-sdk-linux

# Android Linux NDK
# See http://developer.android.com/tools/sdk/ndk/index.html
RUN wget -O /tmp/android-ndk.zip http://dl.google.com/android/repository/android-ndk-r12b-linux-x86_64.zip && \
	unzip /tmp/android-ndk.zip -d /opt/ && \
	rm -f /tmp/android-ndk.zip && \
	chown -R root:root /opt/android-ndk-r12b

# Other tools and resources of Android SDK
ENV ANDROID_HOME=/opt/android-sdk-linux
ENV ANDROID_SDK=/opt/android-sdk-linux
ENV ANDROID_NDK=/opt/android-ndk-r12b
ENV PATH=${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools
RUN echo y | android update sdk --filter ${ANDROID_DEPS} --all --no-ui --force


WORKDIR /home/builder/src
VOLUME /home/builder/src
