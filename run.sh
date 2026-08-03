#!/usr/bin/env bash
set -e

make
qemu-system-x86_64 -drive format=raw,file=build/disk.img