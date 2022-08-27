#!/bin/sh

set -e

export ELIXIR_VER="${1}"
export ELIXIR_ROOT="${2}"
echo "[+] Build Elixir: ${ELIXIR_VER}"
echo "[+] Elixir root: ${ELIXIR_ROOT}"

git clone https://github.com/elixir-lang/elixir.git "${ELIXIR_ROOT}"
pushd "${ELIXIR_ROOT}"
git checkout "${ELIXIR_VER}"
make clean
make install
popd
echo "[+] Elixir: ${ELIXIR_VER}"
echo "[+] ${ELIXIR_ROOT}/bin"
