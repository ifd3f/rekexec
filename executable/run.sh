#!/bin/sh

set -x

exec qemu-system-x86_64 \
            -kernel /boot/kernels/5ngwg33rxpwc476b3bfixdqg4kx9qs62-linux-6.12.69-bzImage \
            -initrd $1 \
            -append "console=ttyS0" \
            -nographic \
            -m 2G \
            -no-reboot
