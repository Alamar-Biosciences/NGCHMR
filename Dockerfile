FROM alpine:3.12.1 as build

MAINTAINER "r-hub admin" admin@r-hub.io

ENV _R_SHLIB_STRIP_=true

ARG R_VERSION=4.1.0

WORKDIR /root

RUN apk update
RUN apk add gcc musl-dev gfortran g++ zlib-dev bzip2-dev xz-dev pcre-dev \
    pcre2-dev curl-dev make perl readline-dev tcl-dev tk-dev libxt-dev libx11-dev

RUN if [[ "$R_VERSION" == "devel" ]]; then                               \
        wget https://stat.ethz.ch/R/daily/R-devel.tar.gz;                \
    elif [[ "$R_VERSION" == "patched" ]]; then                           \
        wget https://stat.ethz.ch/R/daily/R-patched.tar.gz;              \
    else                                                                 \
        wget https://cran.r-project.org/src/base/R-${R_VERSION%%.*}/R-${R_VERSION}.tar.gz; \
    fi
RUN tar xzf R-${R_VERSION}.tar.gz

RUN cd R-${R_VERSION} &&                                                 \
    CXXFLAGS=-D__MUSL__ CFLAGS=-D__MUSL__ ./configure --with-tcltk       \
        --with-recommended-packages=no --with-libpng --with-cairo        \
        --with-readline=yes --with-x=yes --enable-java=no                 \
        --disable-openmp --with-internal-tzcode
RUN cd R-${R_VERSION} && make -j 4
RUN cd R-${R_VERSION} && make install

RUN strip -x /usr/local/lib/R/bin/exec/R
RUN strip -x /usr/local/lib/R/lib/*
RUN find /usr/local/lib/R -name "*.so" -exec strip -x \{\} \;

RUN rm -rf /usr/local/lib/R/library/translations
RUN rm -rf /usr/local/lib/R/doc
RUN mkdir -p /usr/local/lib/R/doc/html
RUN find /usr/local/lib/R/library -name help | xargs rm -rf

RUN find /usr/local/lib/R/share/zoneinfo/America/ -mindepth 1 -maxdepth 1 \
    '!' -name New_York  -exec rm -r '{}' ';'
RUN find /usr/local/lib/R/share/zoneinfo/ -mindepth 1 -maxdepth 1 \
    '!' -name UTC '!' -name America '!' -name GMT -exec rm -r '{}' ';'

RUN sed -i 's/,//g' /usr/local/lib/R/library/utils/iconvlist

RUN touch /usr/local/lib/R/doc/html/R.css

RUN wget https://alamarbio.cloud/ShaidyMapGen.jar

# ----------------------------------------------------------------------------

FROM alpine:3.12.1

ENV _R_SHLIB_STRIP_=true
ENV TZ=UTC

COPY --from=build /usr/local /usr/local
COPY --from=build /root/ShaidyMapGen.jar /usr/local/bin/
ENV SHAIDYMAPGEN=/usr/local/bin/ShaidyMapGen.jar

COPY remotes.R /usr/local/bin/
COPY installr /usr/local/bin/

RUN apk update
RUN apk upgrade --no-cache apk-tools>2.10.7-r0 busybox>1.31.1-r22 musl-utils>1.1.24-r10 expat>2.2.10-r2 git>2.26.3-r1 gmp>6.2.1-r1 zlib>1.2.12-r0 ncurses>6.2_p20200523-r1
RUN apk add --no-cache libgfortran xz-libs libcurl libpcrecpp libbz2 build-base gfortran    \
    pcre2 make readline bash linux-headers m4 libpng-dev tcl tk libx11 libxt curl-dev libxml2-dev
RUN apk add --no-cache libsodium-dev
RUN apk upgrade --no-cache curl>7.79.1-r1 util-linux>2.37.3-r0 xz>5.2.5-r1
RUN apk add --no-cache --update-cache --repository http://nl.alpinelinux.org/alpine/v3.11/main\
    autoconf=2.69-r2 automake=1.16.1-r0
RUN apk add --no-cache git openjdk11 openssh 
RUN installr plumber
#RUN installr jsonline
RUN installr future
RUN installr remotes
RUN installr xml2
RUN R -e "remotes::install_github('Alamar-Biosciences/tsvio', ref='stable')"
RUN R -e "remotes::install_github('Alamar-Biosciences/NGCHM-R', ref='stable')"
RUN R -e "remotes::install_github('Alamar-Biosciences/NGCHMSupportFiles', ref='main')"

EXPOSE 8000
WORKDIR /workingDir
COPY ./.git/refs/heads/main ./
COPY main.R ./
COPY NGCHM.r ./
ENV PATH "$VIRTUAL_ENV/bin:/workingDir:$PATH"
CMD ["main.R"]
