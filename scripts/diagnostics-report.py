#!/usr/bin/env python3
"""Print counts, medians, and 95th percentiles from a Slit diagnostics JSON Lines file.

The input records use the DiagnosticsEvent schema version 1 wire keys. Blank
lines are skipped without being counted; malformed lines are counted and
skipped. This script computes statistics only; it is not device evidence and
sends nothing anywhere.
"""
from pathlib import Path
import argparse
import json
import math
import sys

DURATION_METRICS = [
    ('coldStart', 'Cold start to eligible shutter'),
    ('warmResume', 'Warm resume to eligible shutter'),
    ('requestOverhead', 'Request overhead'),
    ('acceptanceFeedback', 'Acceptance feedback'),
    ('callbackLatency', 'Callback latency (proxy)'),
    ('storageLatency', 'Storage latency'),
    ('backlogDrain', 'Backlog drain'),
]
GATES = {
    'requestOverhead': ('at most 50 ms', 50.0),
    'acceptanceFeedback': ('at most 100 ms', 100.0),
}
KINDS = {'phaseDuration', 'attempt', 'queueLimits', 'configurationSnapshot',
         'thermalState', 'resourceUse'}


def median(values):
    ordered = sorted(values)
    middle = len(ordered) // 2
    if len(ordered) % 2:
        return float(ordered[middle])
    return (ordered[middle - 1] + ordered[middle]) / 2.0


def percentile95(values):
    """Nearest-rank percentile: the ceil(0.95 n)-th smallest value."""
    ordered = sorted(values)
    rank = max(1, math.ceil(0.95 * len(ordered)))
    return float(ordered[rank - 1])


def load(path):
    events, malformed, unsupported = [], 0, 0
    with open(path, encoding='utf-8') as handle:
        for line in handle:
            if not line.strip():
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                malformed += 1
                continue
            if not isinstance(record, dict) or record.get('schemaVersion') != 1 \
                    or record.get('kind') not in KINDS:
                unsupported += 1
                continue
            events.append(record)
    return events, malformed, unsupported


def summarize(events):
    durations, unavailable = {}, {}
    for name, _ in DURATION_METRICS:
        durations[name], unavailable[name] = [], 0
    callbacks = {}
    attempts = {'accepted': 0, 'rejected': 0}
    rejections, failures, inputs, thermal = {}, {}, {}, {}
    peak_memory = preview_stalls = 0
    max_pending = max_occupied = slot_limit = 0
    for event in events:
        kind = event['kind']
        if kind == 'phaseDuration':
            name = event.get('metric')
            if name not in durations:
                continue
            value = event.get('durationMilliseconds')
            if isinstance(value, (int, float)):
                durations[name].append(float(value))
                if name == 'callbackLatency':
                    phase = event.get('callbackPhase', 'unspecified')
                    callbacks.setdefault(phase, []).append(float(value))
            elif value is None:
                unavailable[name] += 1
        elif kind == 'attempt':
            if isinstance(event.get('failureCode'), str):
                failures[event['failureCode']] = failures.get(event['failureCode'], 0) + 1
                continue
            outcome = event.get('outcome')
            if outcome in attempts:
                attempts[outcome] += 1
            if isinstance(event.get('rejectionCategory'), str):
                key = event['rejectionCategory']
                rejections[key] = rejections.get(key, 0) + 1
            if isinstance(event.get('input'), str):
                inputs[event['input']] = inputs.get(event['input'], 0) + 1
        elif kind == 'queueLimits':
            slot_limit = max(slot_limit, event.get('queueLimit') or 0)
            max_occupied = max(max_occupied, event.get('occupiedSlots') or 0)
        elif kind == 'thermalState' and isinstance(event.get('thermalState'), str):
            key = event['thermalState']
            thermal[key] = thermal.get(key, 0) + 1
        elif kind == 'resourceUse':
            peak_memory = max(peak_memory, event.get('peakMemoryBytes') or 0)
            preview_stalls = max(preview_stalls, event.get('previewStallCount') or 0)
            max_pending = max(max_pending, event.get('pendingCount') or 0)
    return {
        'durations': durations, 'unavailable': unavailable, 'callbacks': callbacks,
        'attempts': attempts, 'rejections': rejections, 'failures': failures,
        'inputs': inputs, 'thermal': thermal, 'peakMemoryBytes': peak_memory,
        'previewStalls': preview_stalls, 'maxPending': max_pending,
        'maxOccupiedSlots': max_occupied, 'slotLimit': slot_limit,
    }


def report(source, events, malformed, unsupported, data):
    lines = [f'Source: {source}',
             f'Lines parsed: {len(events)}; malformed skipped: {malformed}; '
             f'unsupported skipped: {unsupported}',
             '', 'Duration measurements in milliseconds (monotonic)',
             'Metric | Count | Unavailable | Median | 95th percentile | Min | Max']
    lines += ['--- | ---: | ---: | ---: | ---: | ---: | ---:']
    for name, label in DURATION_METRICS:
        values = data['durations'][name]
        if values:
            lines.append(f'{label} | {len(values)} | {data["unavailable"][name]} | '
                         f'{median(values):.1f} | {percentile95(values):.1f} | '
                         f'{min(values):.1f} | {max(values):.1f}')
        else:
            lines.append(f'{label} | 0 | {data["unavailable"][name]} | - | - | - | -')
    if data['callbacks']:
        lines += ['', 'Callback proxy latency by phase, milliseconds',
                  'Phase | Count | Median | 95th percentile']
        lines += ['--- | ---: | ---: | ---:']
        for phase in sorted(data['callbacks']):
            values = data['callbacks'][phase]
            lines.append(f'{phase} | {len(values)} | {median(values):.1f} | '
                         f'{percentile95(values):.1f}')
    accepted, rejected = data['attempts']['accepted'], data['attempts']['rejected']
    observed = accepted + rejected
    fraction = f'{accepted / observed:.3f}' if observed else '-'
    lines += ['', 'Application-observed attempts',
              f'Observed: {observed}; accepted: {accepted}; rejected: {rejected}; '
              f'accepted fraction: {fraction}']
    if data['rejections']:
        lines += ['Rejection category | Count'] + ['--- | ---:']
        lines += [f'{key} | {data["rejections"][key]}' for key in sorted(data['rejections'])]
    if data['inputs']:
        lines += ['Input source | Observed attempts'] + ['--- | ---:']
        lines += [f'{key} | {data["inputs"][key]}' for key in sorted(data['inputs'])]
    if data['failures']:
        lines += ['Failure code | Count'] + ['--- | ---:']
        lines += [f'{key} | {data["failures"][key]}' for key in sorted(data['failures'])]
    lines += ['', 'Context and resource use',
              f'Thermal states: {dict(sorted(data["thermal"].items())) or "none recorded"}',
              f'Peak memory bytes: {data["peakMemoryBytes"]}',
              f'Peak preview stalls: {data["previewStalls"]}',
              f'Peak pending saves: {data["maxPending"]}',
              f'Slot limit: {data["slotLimit"]}; peak occupied slots: {data["maxOccupiedSlots"]}']
    lines += ['', 'Application-overhead gates (informational)']
    for name, (text, gate) in GATES.items():
        values = data['durations'][name]
        if values:
            verdict = 'within' if percentile95(values) <= gate else 'over'
            lines.append(f'{name}: 95th percentile {percentile95(values):.1f} ms '
                         f'is {verdict} the gate {text}')
        else:
            lines.append(f'{name}: no samples')
    lines += ['', 'Medians use the mean of the two middle values; percentiles use '
                  'the nearest-rank method.', 'Statistics only. Not device evidence.']
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('input', help='Diagnostics JSON Lines file to read')
    parser.add_argument('--json', action='store_true', help='Print JSON instead of text')
    arguments = parser.parse_args()
    path = Path(arguments.input)
    if not path.is_file():
        print(f'Not a readable file: {path}', file=sys.stderr)
        return 1
    events, malformed, unsupported = load(path)
    data = summarize(events)
    if arguments.json:
        summary = {'source': str(path), 'parsed': len(events), 'malformed': malformed,
                   'unsupported': unsupported, 'attempts': data['attempts'],
                   'metrics': {name: {
                       'count': len(values),
                       'median': median(values) if values else None,
                       'p95': percentile95(values) if values else None,
                       'unavailable': data['unavailable'][name],
                   } for name, values in data['durations'].items()}}
        print(json.dumps(summary, indent=2, sort_keys=True))
    else:
        print(report(path.name, events, malformed, unsupported, data))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
