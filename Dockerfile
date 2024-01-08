#
# Build an s2-py wheel for Ubuntu jammy and python 3.10
# Usage:
#    for ARCH in amd64 arm64/v8 ; do 
#        TAG="s2geometry-builder-$ARCH"
#        docker buildx build --load --platform="linux/$ARCH" -t "$TAG" . \
#        && docker run --rm -v $(pwd)/dist:/dist "$TAG"
#    done
#
# Output goes to dist/*.whl
#


FROM debian:bookworm-slim

ARG BUILDPLATFORM
ARG TARGETPLATFORM
RUN echo " build: ${BUILDPLATFORM} target: ${TARGETPLATFORM}"


RUN apt update -q
RUN apt install -y cmake libssl-dev swig4.0 libgtest-dev git build-essential python3 python3-setuptools python3-wheel python3-dev

# https://github.com/abseil/abseil-cpp/blob/master/CMake/README.md#traditional-cmake-set-up
RUN mkdir -p /source /build
# this commit hash is the commit it definitely worked at. Feel free to update it
RUN git clone https://github.com/abseil/abseil-cpp.git /source/abseil-cpp \
    && cd /source/abseil-cpp \
    && git checkout 9e408e050ff3c1db12f9a58081b6af10e05561c4

# This patch is needed to force Abseil to define `absl::string_view`, which s2-py uses.
# Without the patch, it may or may not be available depending on C++ standard being used.
# (When using C++17 it isn't defined, but with C++14 it is 🤷‍♀️)
RUN cd /source/abseil-cpp/ \
    && sed -i 's/^#define ABSL_OPTION_USE_\(.*\) 2/#define ABSL_OPTION_USE_\1 0/' "absl/base/options.h"

# CMAKE_CXX_STANDARD/ABSL_CXX_STANDARD:
# If you don't be damned sure these are set to the same value for both abseil and the following wheel build,
# you get weird runtime errors because some garbley symbol isn't defined.
# https://github.com/abseil/abseil-cpp/issues/696
# Here (and in setup.py) we define them to be always C++17
ENV CMAKE_CXX_STANDARD=17
RUN cmake -S /source/abseil-cpp -B /build/abseil-cpp \
    -DABSL_CXX_STANDARD=${CMAKE_CXX_STANDARD} \
    -DCMAKE_CXX_STANDARD=${CMAKE_CXX_STANDARD} \
    -DCMAKE_PREFIX_PATH=/installation/dir \
    -DCMAKE_INSTALL_PREFIX=/installation/dir \
    -DABSL_ENABLE_INSTALL=ON \
    -DABSL_USE_EXTERNAL_GOOGLETEST=ON \
    -DABSL_FIND_GOOGLETEST=ON \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
RUN cmake --build /build/abseil-cpp --target install

COPY . /s2py-src
RUN mkdir /dist

WORKDIR /s2py-src
VOLUME /dist

ENV CMAKE_PREFIX_PATH=/installation/dir
CMD ["python3", "setup.py", "bdist_wheel", "--dist-dir", "/dist"]
