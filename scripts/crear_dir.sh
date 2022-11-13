#!/bin/bash

mkdir -pv $QBIT/{etc,var} $QBIT/usr/{bin,lib,sbin}

for i in bin lib sbin; do
  ln -sv usr/$i $QBIT/$i
done

case $(uname -m) in
  x86_64) mkdir -pv $QBIT/lib64 ;;
esac

