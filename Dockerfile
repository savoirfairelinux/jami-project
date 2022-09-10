FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    autopoint \
    bison \
    build-essential \
    cmake \
    curl \
    git \
    libasound2-dev \
    libdbus-1-dev \
    libexpat1-dev \
    libpulse-dev \
    libtool \
    libudev-dev \
	libva-dev \
    libvdpau-dev \
    nasm \
    pkg-config \
	yasm

# Install Node
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - && \
	apt-get install -y nodejs && \
    npm install -g node-gyp

# Install latest Swig (4.1)
WORKDIR /swig
RUN	git clone https://github.com/swig/swig.git && \
    cd swig && \
    ./autogen.sh && \
    ./configure && \
    make -j$(nproc) && \
    make install

WORKDIR /daemon
COPY daemon .

# Build daemon dependencies
RUN mkdir -p contrib/native && \
    cd contrib/native && \
    ../bootstrap && \
    make -j$(nproc)

# Build the daemon
RUN ./autogen.sh && \
    ./configure --with-nodejs && \
    make -j$(nproc)

WORKDIR /web

RUN apt-get update && apt-get install -y \
    lldb \
    liblldb-dev

COPY client-web .
ENV LD_LIBRARY_PATH=/daemon/src/.libs
ENV SECRET_KEY_BASE=test123
RUN npm install && \
    ln -s /daemon/bin/nodejs/build/Release/jamid.node jamid.node && \
	npm run build

CMD ["npm", "start"]
