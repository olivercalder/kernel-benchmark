#!/bin/sh

##### WARNING: HAVING DOCKER DAEMON RUNNING MAY CAUSE OTHER BENCHMARKS TO FAIL #####

# Please install Docker AFTER running the other benchmarks with
# `sh run_benchmarks.sh` and then run this script

run_docker() {
    echo "Benchmarking Docker with timestep of $1 trial 1"
    sh benchmark_docker.sh -o docker-results-r$1.txt -p docker-output-r$1 -r $1 -w 120 -t 60 -m 2>/dev/null
    echo "Benchmarking Docker with timestep of $1 trial 2"
    sh benchmark_docker.sh -o docker-results-r$1.txt -p docker-output-r$1 -r $1 -w 120 -t 60 -m 2>/dev/null
    echo "Benchmarking Docker with timestep of $1 trial 3"
    sh benchmark_docker.sh -o docker-results-r$1.txt -p docker-output-r$1 -r $1 -w 120 -t 60 -m 2>/dev/null
    }
run_docker 4
run_docker 2
run_docker 1
run_docker 0.5
run_docker 0.25
run_docker 0.125
run_docker 0.0625
