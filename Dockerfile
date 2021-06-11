#Source: https://gitee.com/open64ark/open64
#build fail on ubuntu 18.04 and up
ARG DOCKER_IMAGE=ubuntu:16.04
FROM $DOCKER_IMAGE AS builder

RUN apt-get update && apt-get -y install \
	g++ \
	git \
	make \
	gawk \
	csh \
	mercurial \
    gcc-multilib g++-multilib \
	ninja-build \
	ca-certificates \
	ccache \
	flex \
	bison \
	build-essential \
	wget \
#	--no-install-recommends \
	&& apt-get -y autoremove --purge \
	&& rm -rf /var/lib/apt/lists/*

ENV version=3.14
ENV build=7
RUN wget https://cmake.org/files/v$version/cmake-$version.$build.tar.gz
RUN tar xzvf cmake-$version.$build.tar.gz*
RUN cd cmake-$version.$build/ && ./bootstrap && make -j$(nproc) && make install

RUN wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/llvm-11.0.0.src.tar.xz
RUN tar xf llvm-11.0.0.src.tar.xz
RUN wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/clang-11.0.0.src.tar.xz
RUN tar xf clang-11.0.0.src.tar.xz
RUN ln -sf `pwd`/clang-11.0.0.src llvm-11.0.0.src/tools/clang
RUN mkdir /build
WORKDIR /build

RUN cmake -DCMAKE_INSTALL_PREFIX=../11.0.0/release \
	-DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=host \
	-DLLVM_USE_LINKER=gold -DLLVM_ENABLE_LIBEDIT=OFF \
	-DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_LIBPFM=OFF \
	-DLLVM_ENABLE_LIBXML2=OFF -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
	-DCLANG_ENABLE_ARCMT=OFF -DLLVM_ENABLE_TERMINFO=OFF \
	-DLLVM_ENABLE_CRASH_OVERRIDES=OFF -DLLVM_ENABLE_PIC=OFF \
	-DLLVM_ENABLE_BINDINGS=OFF -DLLVM_ENABLE_OCAMLDOC=OFF \
	-GNinja ../llvm-11.0.0.src
RUN ninja
RUN ninja install
ENV CLANG_HOME=/11.0.0/release

WORKDIR /
RUN git clone --recurse-submodules https://gitee.com/open64ark/open64.git

RUN mkdir obj
WORKDIR /obj

#--with-build-optimize=DEBUG --prefix=/usr/local
RUN ../open64/configure --disable-fortran --build=x86_64-linux-gnu --target=x86_64-linux-gnu --with-build-optimize=DEBUG --disable-multilib

RUN make VERBOSE=1 all -j$(nproc)
RUN make install

RUN cd /cmake-$version.$build && make uninstall

ARG DOCKER_IMAGE=ubuntu:16.04
FROM $DOCKER_IMAGE AS runtime

LABEL author="Bensuperpc <bensuperpc@gmail.com>"
LABEL mantainer="Bensuperpc <bensuperpc@gmail.com>"

ARG VERSION="1.0.0"
ENV VERSION=$VERSION

RUN apt-get update && apt-get -y install \
	make \
	g++ \
	--no-install-recommends \
	&& apt-get -y autoremove --purge \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local /usr/local

ENV PATH="/usr/local/bin:${PATH}"
RUN opencc -v
ENV CC=/usr/local/bin/opencc \
	CXX=/usr/local/bin/opencc

WORKDIR /usr/src/myapp

CMD ["opencc", "-v"]

LABEL org.label-schema.schema-version="1.0" \
	  org.label-schema.build-date=$BUILD_DATE \
	  org.label-schema.name="bensuperpc/open64" \
	  org.label-schema.description="build open64 compiler" \
	  org.label-schema.version=$VERSION \
	  org.label-schema.vendor="Bensuperpc" \
	  org.label-schema.url="http://bensuperpc.com/" \
	  org.label-schema.vcs-url="https://github.com/Bensuperpc/docker-open64" \
	  org.label-schema.vcs-ref=$VCS_REF \
	  org.label-schema.docker.cmd="docker build -t bensuperpc/open64 -f Dockerfile ."
