#!/usr/bin/env python3

import sys

benchmarks = {}
for filename in sys.argv[1:]:
    with open(filename) as infile:
        count = 0
        bench_id = ''
        begin_ts = 0
        for line in infile:
            if 'BEGIN BENCHMARK' in line:
                if bench_id:
                    print('ERROR: Benchmarks overlap in file {}'.format(filename), file=sys.stderr)
                    exit(1)
                bench_id = line.split()[3]
                begin_ts = int(line.split()[5])
            elif 'END BENCHMARK' in line:
                end_id = line.split()[3]
                if bench_id == '':
                    print('ERROR: Benchmark ID {} beginning not found in file {}'.format(end_id, filename), file=sys.stderr)
                    exit(1)
                if end_id != bench_id:
                    print('ERROR: Benchmarks overlap in file {}'.format(filename), file=sys.stderr)
                    exit(1)
                if bench_id in benchmarks:
                    print('ERROR: Benchmark ID {} not unique'.format(bench_id), file=sys.stderr)
                    exit(1)
                end_ts = int(line.split()[5])
                time_ns = end_ts - begin_ts
                time_minutes = time_ns / 60000000000
                benchmarks[(filename, bench_id)] = count / time_minutes
                count = 0
                bench_id = ''
            elif bench_id:
                count += 1
        if bench_id:
            print('ERROR: Benchmark {} has no end tag in file {}'.format(bench_id, filename), file=sys.stderr)
            exit(1)

print('Found {} benchmarks'.format(len(benchmarks)))
throughputs = 0
for bench in sorted(benchmarks):
    print('ID: {}\tThroughput: {} per minute'.format(bench, benchmarks[bench]))
    throughputs += benchmarks[bench]
avg_throughput = throughputs / len(benchmarks)
print('Average throughput: {} per minute'.format(avg_throughput))
