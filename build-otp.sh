#!/bin/sh

set -e

export OTP_VER="${1}"
echo "[+] Build OTP: ${OTP_VER}"

sudo apt update && sudo apt install -y \
    autoconf automake \
    libtool zlib1g-dev \
    git build-essential \
    libssl-dev libncurses-dev \
    pkg-config bc m4 zip make curl

curl -fSL "https://github.com/erlang/otp/releases/download/OTP-${OTP_VER}/otp_src_${OTP_VER}.tar.gz" -o "otp_src_${OTP_VER}.tar.gz"
tar xf "otp_src_${OTP_VER}.tar.gz"
rm -rf "otp_src_${OTP_VER}.tar.gz"
pushd "otp_src_${OTP_VER}"
./configure
make -j"$(nproc)"
make install
popd
echo "[+] OTP: ${OTP_VER}"
