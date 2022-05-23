#
# Build an s2-py wheel for a particular version of python.
# Usage:
#    for PYTHON_VERSION in 3.7 3.8 ; do
#      docker build --build-arg "PYTHON_VERSION=$PYTHON_VERSION" -t s2geometry-builder . \
#      && docker run --rm -v $(pwd)/dist:/dist s2geometry-builder
#    done
#
# Output goes to dist/*.whl
#

ARG PYTHON_VERSION
FROM python:${PYTHON_VERSION}

RUN apt update -q
RUN apt install -y cmake libssl-dev swig4.0 libgtest-dev git build-essential

# https://github.com/abseil/abseil-cpp/blob/master/CMake/README.md#traditional-cmake-set-up
RUN mkdir -p /source /build
RUN git clone https://github.com/abseil/abseil-cpp.git /source/abseil-cpp

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
CMD ["python3", "setup.py", "bdist_wheel", "--dist-dir", "/dist"]
