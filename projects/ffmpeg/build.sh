#!/bin/bash -ex
# Copyright 2016 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

OUT="/"

# Disable UBSan vptr since several targets built with -fno-rtti.
export CFLAGS="$CFLAGS -fno-sanitize=vptr"
export CXXFLAGS="$CXXFLAGS -fno-sanitize=vptr"

if [[ "$ARCHITECTURE" == i386 ]]; then
  export CFLAGS="$CFLAGS -m32"
  export CXXFLAGS="$CXXFLAGS -m32"
fi

# Build dependencies.
export FFMPEG_DEPS_PATH=/ffmpeg_deps
mkdir -p $FFMPEG_DEPS_PATH

export PATH="$FFMPEG_DEPS_PATH/bin:$PATH"
export LD_LIBRARY_PATH="$FFMPEG_DEPS_PATH/lib"

mkdir -p $OUT/lib/
cp /usr/lib/aarch64-linux-gnu/libbz2.so.1.0 $OUT/lib/
cp /usr/lib/aarch64-linux-gnu/libz.so.1 $OUT/lib/

cd /
bzip2 -f -d alsa-lib-*
tar xf alsa-lib-*
rm alsa-lib-*.tar
cd alsa-lib-*
./configure --prefix="$FFMPEG_DEPS_PATH" --enable-static --disable-shared
make clean
make -j$(nproc) all
make install

cd /fdk-aac
autoreconf -fiv
CXXFLAGS="$CXXFLAGS -fno-sanitize=shift-base,signed-integer-overflow" \
./configure --prefix="$FFMPEG_DEPS_PATH" --disable-shared
make clean
make -j$(nproc) all
make install

cd /libva
./autogen.sh
./configure --prefix="$FFMPEG_DEPS_PATH" --enable-static --disable-shared
make clean
make -j$(nproc) all
make install

cd /libvdpau
./autogen.sh
./configure --prefix="$FFMPEG_DEPS_PATH" --enable-static --disable-shared
make clean
make -j$(nproc) all
make install

cd /libvpx
TARGET=""

LDFLAGS="$CXXFLAGS" ./configure --prefix="$FFMPEG_DEPS_PATH" \
        --disable-examples --disable-unit-tests \
        --size-limit=12288x12288 \
        --extra-cflags="-DVPX_MAX_ALLOCABLE_MEMORY=1073741824" \
        $TARGET

make clean
make -j$(nproc) all
make install

cd /ogg
./autogen.sh
./configure --prefix="$FFMPEG_DEPS_PATH" --enable-static --disable-crc
make clean
make -j$(nproc)
make install

cd /opus
./autogen.sh
./configure --prefix="$FFMPEG_DEPS_PATH" --enable-static
make clean
make -j$(nproc) all
make install

cd /theora
THEORA_BUILD_ARGS=''
# theora requires ogg, need to pass its location to the "configure" script.
CFLAGS="$CFLAGS -fPIC" LDFLAGS="-L$FFMPEG_DEPS_PATH/lib/" \
      CPPFLAGS="$CXXFLAGS -I$FFMPEG_DEPS_PATH/include/" \
      LD_LIBRARY_PATH="$FFMPEG_DEPS_PATH/lib/" \
      ./autogen.sh
./configure --with-ogg="$FFMPEG_DEPS_PATH" --prefix="$FFMPEG_DEPS_PATH" \
      --enable-static --disable-examples $THEORA_BUILD_ARGS
make clean
make -j$(nproc)
make install

cd /vorbis
./autogen.sh
./configure --prefix="$FFMPEG_DEPS_PATH" --enable-static
make clean
make -j$(nproc)
make install

cd /libxml2
./autogen.sh --prefix="$FFMPEG_DEPS_PATH" --enable-static \
      --without-debug --without-ftp --without-http \
      --without-legacy --without-python
make clean
make -j$(nproc)
make install

# Remove shared libraries to avoid accidental linking against them.
rm $FFMPEG_DEPS_PATH/lib/*.so
rm $FFMPEG_DEPS_PATH/lib/*.so.*

# Build ffmpeg.
cd /ffmpeg
FFMPEG_BUILD_ARGS=''

export CC="clang"
export CXX="clang++"
# export CFLAGS="-g -fsanitize=fuzzer-no-link,address,integer,bounds,null,undefined,float-divide-by-zero"
# export CXXFLAGS="-g -fsanitize=fuzzer-no-link,address,integer,bounds,null,undefined,float-divide-by-zero"
# export LDFLAGS="$CFLAGS"

PKG_CONFIG_PATH="$FFMPEG_DEPS_PATH/lib/pkgconfig" ./configure \
        --cc=$CC --cxx=$CXX --ld="$CXX $LDFLAGS -std=c++11" \
        --extra-cflags="-I$FFMPEG_DEPS_PATH/include" \
        --extra-ldflags="-L$FFMPEG_DEPS_PATH/lib" \
        --prefix="$FFMPEG_DEPS_PATH" \
        --pkg-config-flags="--static" \
        --libfuzzer=$LIB_FUZZING_ENGINE \
        --optflags=-O1 \
        --enable-gpl \
        --enable-nonfree \
        --enable-libass \
        --enable-libfdk-aac \
        --enable-libfreetype \
        --enable-libopus \
        --enable-libtheora \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libxml2 \
        --enable-nonfree \
        --disable-muxers \
        --disable-protocols \
        --disable-demuxer=rtp,rtsp,sdp \
        --disable-devices \
        --disable-shared \
        $FFMPEG_BUILD_ARGS
make clean
make -j$(nproc) install

# Download test samples, will be used as seed corpus.
# DISABLED.
# TODO: implement a better way to maintain a minimized seed corpora
# for all targets. As of 2017-05-04 now the combined size of corpora
# is too big for ClusterFuzz (over 10Gb compressed data).
export TEST_SAMPLES_PATH=/ffmpeg/fate-suite/
make fate-rsync SAMPLES=$TEST_SAMPLES_PATH
