#!/bin/sh

pgrep -f "sh start_rust.*" | xargs -n1 kill
pgrep -f "sh benchmark_rust.*" | xargs -n1 kill
pkill cat
pkill qemu
