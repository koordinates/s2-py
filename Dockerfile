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

FROM ubuntu:jammy

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

# If you don't be damned sure these are set to the same value for both abseil and the following wheel build,
# you get weird runtime errors because some garbley symbol isn't defined.
# https://github.com/abseil/abseil-cpp/issues/696
# Also, in my testing C++17 didn't seem to actually work; I had to set them back to C++11 to make it work.
ENV ABSL_CXX_STANDARD=11
ENV CMAKE_CXX_STANDARD=11
RUN cmake -S /source/abseil-cpp -B /build/abseil-cpp -DCMAKE_PREFIX_PATH=/installation/dir -DCMAKE_INSTALL_PREFIX=/installation/dir -DABSL_ENABLE_INSTALL=ON -DABSL_USE_EXTERNAL_GOOGLETEST=ON -DABSL_FIND_GOOGLETEST=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON
RUN cmake --build /build/abseil-cpp --target install

COPY . /s2py-src
RUN mkdir /dist

WORKDIR /s2py-src
VOLUME /dist

ENV CMAKE_PREFIX_PATH=/installation/dir
CMD ["python3.10", "setup.py", "bdist_wheel", "--dist-dir", "/dist"]
