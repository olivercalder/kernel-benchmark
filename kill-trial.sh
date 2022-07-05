#!/bin/sh

pgrep -f "sh start_$1.*" | xargs -n1 kill
pgrep -f "sh benchmark_$1.*" | xargs -n1 kill
pkill cat
pkill qemu
