#!/usr/bin/env python3

from itertools import groupby
from statistics import mean
import sys, os

from matplotlib.image import thumbnail
from numpy import extract
EXPECTED_THUMB_SIZE = 1670 # larger.png cropped to 150x150

benchmarks = {}
for filename in sys.argv[1:]:
    print(filename)
    with open(filename) as infile:
        count = 0
        total_latency = 0
        bench_id = ''
        begin_ts = 0
        # expecting filenames like `benchmark-data/Benchmark-1651612882/podman-results-r2.txt`
        datadir, datafile = os.path.split(filename)
        app = datafile.split('-')[0]
        outdir = f"{datadir}/{datafile.rsplit('.', 1)[0].replace('results', 'output')}"
        for line in infile:
            line = line.strip()
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
                benchmarks[(filename, bench_id)] = (count / time_minutes, total_latency / count) if count > 0 else None
                count = 0
                total_latency = 0
                bench_id = ''
            elif bench_id:
                outfile = f"{outdir}/{app}-{line}"
                thumbfile = f"{outdir}/{app}-{line}/thumbnail.png" if app == "podman" else f"{outfile}.png"
                # if the thumbnail file exists and is the expected size, we'll assume the instance succeeded
                if os.path.exists(thumbfile) and os.path.getsize(thumbfile) == EXPECTED_THUMB_SIZE:
                    count += 1
                    with open(f"{outfile}.output") as of:
                        outlines = of.readlines()
                        assert len([l for l in outlines if l.startswith("real")]) == 1
                        total_latency += float(next(l for l in outlines if l.startswith("real")).split()[1])


        if bench_id:
            print('ERROR: Benchmark {} has no end tag in file {}'.format(bench_id, filename), file=sys.stderr)
            exit(1)

# x is dict item, x[0] is (filename, bench_id), os.path.split(x[0][0])[1] is tail of filename
def extract_trial_name(x): return os.path.split(x[0][0])[1]
groups = {b: tuple(zip(*[v for _, v in vals])) for b, vals in groupby(sorted(benchmarks.items(), key=extract_trial_name), key=extract_trial_name)}
average_perfs = {k: (mean(ts), mean(ls)) for k, (ts, ls) in groups.items()}

print('Found {} benchmarks'.format(len(benchmarks)))
# print results
for bench in sorted(benchmarks):
    print('ID: {}\tThroughput: {} per minute'.format(bench, benchmarks[bench]))
# write results to csv file
with open("avg_perfs.csv", 'w') as outfile:
    outfile.write("benchmark,throughput,latency\n")
    for benchmark, (throughput, latency) in average_perfs.items():
        outfile.write(f"{benchmark},{throughput},{latency}\n")
