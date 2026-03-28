#!/bin/sh

set -x

script=$(dirname $(readlink -f $0))/run.sh

echo ':cpio:M::\x30\x37\x30\x37\x30\x31::'"$script:" \
  > /proc/sys/fs/binfmt_misc/register
