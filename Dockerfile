FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ============================================================
# Base development environment
# ============================================================

RUN apt-get update && \
    apt-get install -y \
        build-essential \
        gcc \
        g++ \
        make \
        cmake \
        ninja-build \
        pkg-config \
        git \
        git-lfs \
        curl \
        wget \
        ca-certificates \
        gnupg \
        software-properties-common \
        sudo \
        bash-completion \
        vim \
        nano \
        less \
        tree \
        file \
        xxd \
        unzip \
        zip \
        rsync \
        patch \
        diffutils \
        shellcheck \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# C++ / CMake / LLVM development
# ============================================================

RUN apt-get update && \
    apt-get install -y \
        clang \
        clangd \
        clang-format \
        clang-tidy \
        clang-tools \
        llvm \
        llvm-dev \
        lld \
        llvm-runtime \
        libc++-dev \
        libc++abi-dev \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Autotools
#
# Required by some vcpkg ports, especially libedit.
# autoconf-archive is important here.
# ============================================================

RUN apt-get update && \
    apt-get install -y \
        autoconf \
        autoconf-archive \
        automake \
        libtool \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Debugging
# ============================================================

RUN apt-get update && \
    apt-get install -y \
        gdb \
        gdbserver \
        gdb-multiarch \
        lldb \
        strace \
        ltrace \
        valgrind \
        valgrind-mpi \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# ELF / DWARF / binary analysis
#
# objdump, readelf, nm, addr2line, etc. come from binutils.
# ============================================================

RUN apt-get update && \
    apt-get install -y \
        binutils \
        binutils-multiarch \
        elfutils \
        libelf-dev \
        libdw-dev \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Useful debugging / runtime libraries
# ============================================================

RUN apt-get update && \
    apt-get install -y \
        libedit-dev \
        libunwind-dev \
        libffi-dev \
        zlib1g-dev \
        libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Testing / static analysis
# ============================================================

RUN apt-get update && \
    apt-get install -y \
        cppcheck \
        gcovr \
        lcov \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# System / process inspection
# ============================================================

RUN apt-get update && \
    apt-get install -y \
        procps \
        psmisc \
        util-linux \
        kmod \
        iproute2 \
        net-tools \
        pciutils \
        usbutils \
        lsof \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Python
#
# Useful for ELF/DWARF experiments, helper scripts,
# test automation, etc.
# ============================================================

RUN apt-get update && \
    apt-get install -y \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
        python3-setuptools \
        python3-wheel \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --no-cache-dir \
        pyelftools \
        capstone \
        lief \
        pytest

# ============================================================
# vcpkg
#
# The book explicitly uses vcpkg.
#
# Current sdb repository dependencies:
#   libedit
#   catch2
#   fmt
#   zydis
# ============================================================

ENV VCPKG_ROOT=/opt/vcpkg

RUN git clone --depth 1 \
        https://github.com/microsoft/vcpkg.git \
        /opt/vcpkg && \
    /opt/vcpkg/bootstrap-vcpkg.sh -disableMetrics

ENV PATH="/opt/vcpkg:$PATH"

# ============================================================
# Pre-fetch the book's dependencies
#
# This validates the vcpkg environment during the image build
# and leaves the downloaded/build artifacts cached in the image.
# ============================================================

RUN mkdir -p /opt/sdb-vcpkg-bootstrap && \
    printf '%s\n' \
        '{' \
        '  "dependencies": [' \
        '    "libedit",' \
        '    "catch2",' \
        '    "fmt",' \
        '    "zydis"' \
        '  ]' \
        '}' \
        > /opt/sdb-vcpkg-bootstrap/vcpkg.json && \
    cd /opt/sdb-vcpkg-bootstrap && \
    /opt/vcpkg/vcpkg install --triplet x64-linux

# ============================================================
# x86-64 helpers
# ============================================================

RUN cat > /usr/local/bin/x64-gcc <<'EOF'
#!/bin/sh
exec gcc -m64 "$@"
EOF

RUN chmod +x /usr/local/bin/x64-gcc

RUN cat > /usr/local/bin/x64-clang <<'EOF'
#!/bin/sh
exec clang -m64 "$@"
EOF

RUN chmod +x /usr/local/bin/x64-clang

# ============================================================
# Environment information helper
# ============================================================

RUN cat > /usr/local/bin/debug-info <<'EOF'
#!/bin/sh

echo "=============================================="
echo " Debugger Environment"
echo "=============================================="

echo
echo "=== Architecture ==="
uname -m

echo
echo "=== GCC ==="
gcc --version | head -n 1

echo
echo "=== Clang ==="
clang --version | head -n 1

echo
echo "=== CMake ==="
cmake --version | head -n 1

echo
echo "=== Ninja ==="
ninja --version

echo
echo "=== GDB ==="
gdb --version | head -n 1

echo
echo "=== LLDB ==="
lldb --version | head -n 1

echo
echo "=== Binutils ==="
objdump --version | head -n 1

echo
echo "=== ELF/DWARF ==="
eu-readelf --version 2>/dev/null | head -n 1 || true

echo
echo "=== vcpkg ==="
vcpkg version | head -n 1

echo
echo "=== VCPKG_ROOT ==="
echo "$VCPKG_ROOT"

echo
echo "=============================================="
EOF

RUN chmod +x /usr/local/bin/debug-info

# ============================================================
# ELF inspection helper
# ============================================================

RUN cat > /usr/local/bin/elf-info <<'EOF'
#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "Usage: elf-info <binary>"
    exit 1
fi

FILE="$1"

echo "=================================================="
echo "FILE"
echo "=================================================="
file "$FILE"

echo
echo "=================================================="
echo "ELF HEADER"
echo "=================================================="
readelf -h "$FILE"

echo
echo "=================================================="
echo "PROGRAM HEADERS"
echo "=================================================="
readelf -l "$FILE"

echo
echo "=================================================="
echo "SECTION HEADERS"
echo "=================================================="
readelf -S "$FILE"

echo
echo "=================================================="
echo "SYMBOLS"
echo "=================================================="
readelf -Ws "$FILE"
EOF

RUN chmod +x /usr/local/bin/elf-info

# ============================================================
# DWARF inspection helper
# ============================================================

RUN cat > /usr/local/bin/dwarf-info <<'EOF'
#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "Usage: dwarf-info <binary>"
    exit 1
fi

FILE="$1"

echo "=================================================="
echo "DWARF INFO"
echo "=================================================="
readelf --debug-dump=info "$FILE"

echo
echo "=================================================="
echo "LINE TABLE"
echo "=================================================="
readelf --debug-dump=decodedline "$FILE"

echo
echo "=================================================="
echo "FRAME INFO"
echo "=================================================="
readelf --debug-dump=frames "$FILE"
EOF

RUN chmod +x /usr/local/bin/dwarf-info

# ============================================================
# Disassembly helper
# ============================================================

RUN cat > /usr/local/bin/disasm <<'EOF'
#!/bin/sh

if [ "$#" -lt 1 ]; then
    echo "Usage: disasm <binary> [objdump options]"
    exit 1
fi

FILE="$1"
shift

exec objdump \
    -d \
    -Mintel \
    "$@" \
    "$FILE"
EOF

RUN chmod +x /usr/local/bin/disasm

# ============================================================
# GDB helper
# ============================================================

RUN cat > /usr/local/bin/debug-gdb <<'EOF'
#!/bin/sh

if [ "$#" -eq 0 ]; then
    exec gdb -q
else
    exec gdb -q "$@"
fi
EOF

RUN chmod +x /usr/local/bin/debug-gdb

# ============================================================
# LLDB helper
# ============================================================

RUN cat > /usr/local/bin/debug-lldb <<'EOF'
#!/bin/sh

if [ "$#" -eq 0 ]; then
    exec lldb
else
    exec lldb "$@"
fi
EOF

RUN chmod +x /usr/local/bin/debug-lldb

# ============================================================
# Build helper for CMake/vcpkg projects
# ============================================================

RUN cat > /usr/local/bin/cmake-debug <<'EOF'
#!/bin/sh

set -eu

SOURCE_DIR="${1:-.}"
BUILD_DIR="$SOURCE_DIR/out/build/linux-debug"

cmake \
    -S "$SOURCE_DIR" \
    -B "$BUILD_DIR" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_TOOLCHAIN_FILE="${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"

cmake \
    --build "$BUILD_DIR" \
    --parallel
EOF

RUN chmod +x /usr/local/bin/cmake-debug

# ============================================================
# Simple x86-64 compile helper
#
# Useful for creating targets to debug.
# ============================================================

RUN cat > /usr/local/bin/build-debug-target <<'EOF'
#!/bin/sh

set -eu

if [ "$#" -lt 1 ]; then
    echo "Usage: build-debug-target <source.c>"
    exit 1
fi

SOURCE="$1"
OUTPUT="${2:-${SOURCE%.*}}"

gcc \
    -g \
    -O0 \
    -fno-omit-frame-pointer \
    -Wall \
    -Wextra \
    -m64 \
    "$SOURCE" \
    -o "$OUTPUT"

echo "Built: $OUTPUT"
file "$OUTPUT"
EOF

RUN chmod +x /usr/local/bin/build-debug-target

# ============================================================
# ptrace information
# ============================================================

RUN cat > /usr/local/bin/ptrace-info <<'EOF'
#!/bin/sh

echo "=== ptrace capability ==="

if grep -q CapEff /proc/self/status; then
    grep CapEff /proc/self/status
fi

echo
echo "=== Yama ptrace_scope ==="

if [ -r /proc/sys/kernel/yama/ptrace_scope ]; then
    cat /proc/sys/kernel/yama/ptrace_scope
else
    echo "Yama ptrace_scope unavailable"
fi

echo
echo "=== TracerPid ==="

if [ -r /proc/self/status ]; then
    grep TracerPid /proc/self/status || true
fi

echo
echo "For broader ptrace experiments, start the container with:"
echo
echo "  --cap-add=SYS_PTRACE"
echo "  --security-opt seccomp=unconfined"
EOF

RUN chmod +x /usr/local/bin/ptrace-info

# ============================================================
# Workspace
# ============================================================

RUN mkdir -p \
        /workspace \
        /workspace/sdb \
        /workspace/targets \
        /workspace/tests \
        /workspace/assembly \
        /workspace/elf \
        /workspace/dwarf \
        /workspace/scripts \
        /workspace/crashes

WORKDIR /workspace

# ============================================================
# Bash configuration
# ============================================================

RUN cat >> /root/.bashrc <<'EOF'

# ============================================================
# Building a Debugger environment
# ============================================================

export VCPKG_ROOT=/opt/vcpkg
export PATH="$VCPKG_ROOT:$PATH"

alias ll='ls -lah'
alias la='ls -A'

echo
echo "=============================================="
echo " Building a Debugger environment"
echo "=============================================="
echo "Architecture : $(uname -m)"
echo "C++          : GCC / Clang"
echo "CMake        : $(cmake --version | head -n 1)"
echo "Ninja        : $(ninja --version)"
echo "GDB          : $(gdb --version | head -n 1)"
echo "LLDB         : $(lldb --version | head -n 1)"
echo "vcpkg        : $VCPKG_ROOT"
echo
echo "Book source  : /workspace/sdb"
echo
echo "Helpers:"
echo "  debug-info"
echo "  elf-info <binary>"
echo "  dwarf-info <binary>"
echo "  disasm <binary>"
echo "  debug-gdb [binary]"
echo "  debug-lldb [binary]"
echo "  cmake-debug [source-dir]"
echo "  build-debug-target <source.c> [output]"
echo "  ptrace-info"
echo
echo "For ptrace experiments, normally start the container with:"
echo "  --cap-add=SYS_PTRACE"
echo "  --security-opt seccomp=unconfined"
echo "=============================================="
echo

EOF

# ============================================================
# Default command
# ============================================================

CMD ["/bin/bash"]