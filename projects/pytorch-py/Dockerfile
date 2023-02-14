# Copyright 2023 ISP RAS
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

FROM sydr/ubuntu20.04-sydr-fuzz

MAINTAINER Darya Parygina (pa_darochek)

# Install build dependencies.
RUN pip3 install astunparse numpy ninja pyyaml mkl mkl-include setuptools cmake cffi typing_extensions

# Clone target from GitHub.
RUN git clone https://github.com/pytorch/pytorch/ /pytorch
RUN cd /pytorch && \
    git checkout abc54f93145830b502400faa92bec86e05422fbd && \
    git submodule sync --recursive && \
    git submodule update --init --recursive --jobs 0

RUN pip3 uninstall protobuf

# Copy build script and targets.
COPY *.sh \
     *.patch \
     *.cc \
     /

# Apply PyTorch fixes. 
# RUN cd /pytorch && \
#     git apply /schema_type_parser-stoll.patch

# Patch exceptions throwing to avoid unwanted crashes.
# RUN ./patch_exceptions.sh

# Fix PyTorch build.
RUN rm /usr/bin/x86_64-linux-gnu-gcc && \
    ln -s /usr/bin/clang /usr/bin/x86_64-linux-gnu-gcc

# Patch exceptions throwing to avoid unwanted crashes.
# RUN bash patch_exceptions.sh
WORKDIR /

# Build fuzz targets.
RUN chmod +x /build.sh
RUN /build.sh

# Prepare fuzzing corpus.
# COPY ./ir_corpus.zip /
# COPY ./parser_corpus.zip /
# COPY ./corpus_message_deserialize.zip /
# RUN mkdir corpus_torch_script && \
#     find /pytorch -name "*.pt" -exec cp {} ./corpus_torch_script/ \; && \
#     unzip /ir_corpus.zip && \
#     unzip /parser_corpus.zip && \
#     unzip /corpus_message_deserialize.zip
