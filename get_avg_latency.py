#!/usr/bin/env python3

"""
This file is obsolete and no longer compatible with benchmark output.
Use get_avg_perf.py to compute average latency
"""

import os
import sys
import getopt

usage = '''USAGE: python3 {} [OPTIONS] [FILENAME] [...]

OPTIONS:
    -h                          display help message
    -t <type>                   specify the type of output -- REQUIRED
                                options:
                                    linux
                                    rust
                                    docker
                                    process
    -d <directory>              read output files from given directory
'''.format(sys.argv[0])

types = ['linux', 'rust', 'docker', 'process']

try:
    optlist, args = getopt.getopt(sys.argv[1:], 'ht:d:')
except getopt.GetoptError as err:
    print(err, file=sys.stderr)
    print(usage, file=sys.stderr)
    exit(1)

ftype = None
directories = []
for o, a in optlist:
    if o == '-h':
        print(usage, file=sys.stderr)
        exit(1)
    elif o == '-t':
        ftype = a
    elif o == '-d':
        directories.append(a)
    else:
        print('ERROR: option "{}" unrecognized\n'.format(o), file=sys.stderr)
        print(usage, file=sys.stderr)
        exit(1)

for d in directories:
    for f in os.listdir(d):
        args.append('{}/{}'.format(d, f))

latencies = []
questionable = 0
unsuccessful = 0
if ftype == 'linux':
    # Files should have the following form:
    # <timestamp> QEMU initiated
    # <timestamp> VM successfully running
    # <timestamp> QEMU exited successfully
    for filename in args:
        with open(filename) as infile:
            start_ts = None
            active_ts = None
            question = False
            success = False
            for line in infile:
                if 'QEMU initiated' in line:
                    try:
                        start_ts = int(line.split()[0])
                    except ValueError:
                        question = True
                elif 'VM successfully running' in line:
                    try:
                        active_ts = int(line.split()[0])
                    except ValueError:
                        question = True
                elif 'QEMU exited successfully' in line:
                    success = True
            if question:
                questionable += 1
            elif not success:
                unsuccessful += 1
            elif start_ts is None or active_ts is None:
                questionable += 1
            else:
                latency = active_ts - start_ts
                latencies.append(latency)
elif ftype == 'rust':
    # Files should have the following form:
    # <timestamp> QEMU initiated
    # Hello 42!
    # <timestamp> QEMU exited with error code 33
    for filename in args:
        with open(filename) as infile:
            start_ts = None
            exit_ts = None
            question = False
            success = False
            for line in infile:
                if 'QEMU initiated' in line:
                    try:
                        start_ts = int(line.split()[0])
                    except ValueError:
                        question = True
                elif 'QEMU exited with error code 33' in line:
                    try:
                        exit_ts = int(line.split()[0])
                    except ValueError:
                        question = True
                    else:
                        success = True
            if question:
                questionable += 1
            elif not success:
                unsuccessful += 1
            elif start_ts is None or exit_ts is None:
                questionable += 1
            else:
                latency = exit_ts - start_ts
                latencies.append(latency)
elif ftype == 'docker':
    # Files should have the following form:
    # <timestamp> Docker initiated
    # <timestamp> Docker exited successfully
    for filename in args:
        with open(filename) as infile:
            start_ts = None
            exit_ts = None
            question = False
            success = False
            for line in infile:
                if 'Docker initiated' in line:
                    try:
                        start_ts = int(line.split()[0])
                    except ValueError:
                        question = True
                elif 'Docker exited successfully' in line:
                    try:
                        exit_ts = int(line.split()[0])
                    except ValueError:
                        question = True
                    else:
                        success = True
            if question:
                questionable += 1
            elif not success:
                unsuccessful += 1
            elif start_ts is None or exit_ts is None:
                questionable += 1
            else:
                latency = exit_ts - start_ts
                latencies.append(latency)
elif ftype == 'process':
    # Files should have the following form:
    # <timestamp> Process initiated
    # <timestamp> Hello World!
    # <timestamp> Process exited successfully
    for filename in args:
        with open(filename) as infile:
            start_ts = None
            active_ts = None
            question = False
            success = False
            for line in infile:
                if 'Process initiated' in line:
                    try:
                        start_ts = int(line.split()[0])
                    except ValueError:
                        question = True
                elif 'Hello World!' in line:
                    try:
                        active_ts = int(line.split()[0])
                    except ValueError:
                        question = True
                elif 'Process exited successfully' in line:
                    success = True
            if question:
                questionable += 1
            elif not success:
                unsuccessful += 1
            elif start_ts is None or active_ts is None:
                questionable += 1
            else:
                latency = active_ts - start_ts
                latencies.append(latency)
elif ftype is None:
    print('ERROR: please specify an output type using -t\n', file=sys.stderr)
    print(usage, file=sys.stderr)
    exit(1)
else:
    print('ERROR: type {} unrecognized; available types:'.format(ftype), file=sys.stderr)
    [print(t, file=sys.stderr) for t in types]
    exit(1)

print('Found {} successful runs'.format(len(latencies)))
print('Found {} questionable runs'.format(questionable))
print('Found {} unsuccessful runs'.format(unsuccessful))
# dividing by powers of 10 is not precise enough, so I'll do it manually
avg_latency = sum(latencies) // len(latencies)
latency_str = str(avg_latency).zfill(10)
seconds = latency_str[:-9]
nanoseconds = latency_str[-9:]
print('Average latency: {}.{} seconds'.format(seconds, nanoseconds))
