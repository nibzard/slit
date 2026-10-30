#!/usr/bin/env python3
"""Write a deterministic synthetic Slit diagnostics JSON Lines fixture.

The output matches DiagnosticsEvent schema version 1. Values are invented,
seeded numbers for exercising scripts/diagnostics-report.py. The fixture is
not device evidence and contains no photograph, location, or path data.
"""
from pathlib import Path
import argparse
import json
import random
import uuid

SEED = 20261030
SESSION = uuid.UUID('5f1d0b2e-0000-4000-8000-000000000001')


def identifier(index):
    """Stable synthetic app-local identifier; no real capture exists."""
    return f'00000000-0000-4000-8000-{index:012d}'


def base(sequence, kind, **fields):
    record = {'schemaVersion': 1, 'sequence': sequence, 'kind': kind}
    record.update(fields)
    return record


def generate():
    rng = random.Random(SEED)
    events = []
    events.append(base(1, 'configurationSnapshot', sessionId=str(SESSION), configuration={
        'appBuild': 'Slit-Dev-Synthetic', 'osBuild': 'synthetic', 'deviceModel': 'synthetic',
        'rawPixelFormatCode': 'HGVD', 'formatMaximumWidth': 8064,
        'formatMaximumHeight': 6048, 'focusMode': 'continuousAutofocus',
        'captureSlotLimit': 2}))
    counter = 2

    def add(kind, **fields):
        nonlocal counter
        events.append(base(counter, kind, **fields))
        counter += 1

    def durations(metric, count, low, high, **extra):
        for _ in range(count):
            value = round(rng.uniform(low, high), 1)
            fields = {'metric': metric, 'durationMilliseconds': value,
                      'sessionId': str(SESSION)}
            fields.update(extra)
            add('phaseDuration', **fields)

    durations('coldStart', 8, 800, 1600)
    durations('warmResume', 8, 280, 700)
    durations('requestOverhead', 40, 6, 46)
    durations('acceptanceFeedback', 40, 18, 96)
    for index in range(30):
        phase = ['willCapture', 'didFinishCapture', 'didFinishProcessingPhoto'][index % 3]
        add('phaseDuration', metric='callbackLatency', callbackPhase=phase,
            durationMilliseconds=round(rng.uniform(55, 390), 1),
            captureId=identifier(index), sessionId=str(SESSION))
    durations('storageLatency', 30, 380, 1750)
    durations('backlogDrain', 8, 900, 2600, pendingCount=0)

    # A shortened onscreen sequence and received hardware input. Real runs
    # use the specification counts: 100 accepted captures and 50-attempt
    # sequences at one and two attempts per second.
    for index in range(30):
        capture = identifier(100 + index)
        if rng.random() < 0.86:
            add('attempt', input='onscreen', outcome='accepted',
                captureId=capture, sessionId=str(SESSION))
        else:
            category = rng.choice(['capacityReached', 'outputUnavailable',
                                   'storageBlocked', 'inactive', 'screenHidden'])
            add('attempt', input='onscreen', outcome='rejected',
                rejectionCategory=category, sessionId=str(SESSION))
    # The Swift encoder omits an unavailable key instead of writing an
    # explicit null, so absent captureId and rejectionCategory keys are
    # omitted here too.
    for index in range(6):
        source = 'hardwarePrimary' if index % 2 else 'hardwareSecondary'
        fields = {'input': source, 'outcome': 'accepted' if index % 3 else 'rejected',
                  'sessionId': str(SESSION)}
        if index % 3 == 0:
            fields['rejectionCategory'] = 'inactive'
        else:
            fields['captureId'] = identifier(200 + index)
        add('attempt', **fields)
    add('attempt', failureCode='captureFailed', captureId=identifier(300),
        sessionId=str(SESSION))
    add('attempt', failureCode='saveRetained', captureId=identifier(301),
        sessionId=str(SESSION))
    add('attempt', failureCode='previewFailed', captureId=identifier(302),
        sessionId=str(SESSION))

    for occupied in (0, 1, 2, 1, 2):
        add('queueLimits', queueLimit=2, occupiedSlots=occupied, sessionId=str(SESSION))
    for state in ('nominal', 'nominal', 'fair', 'serious', 'fair'):
        add('thermalState', thermalState=state, sessionId=str(SESSION))
    for _ in range(6):
        add('resourceUse', peakMemoryBytes=rng.randrange(90_000_000, 240_000_000),
            pendingCount=rng.randrange(0, 3), occupiedSlots=rng.randrange(0, 3),
            previewStallCount=rng.randrange(0, 4), thermalState='fair',
            sessionId=str(SESSION))
    # One unavailable measurement proves the null path through the tool.
    add('phaseDuration', metric='coldStart', durationMilliseconds=None,
        sessionId=str(SESSION))
    return events


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('output', help='JSON Lines file to write')
    arguments = parser.parse_args()
    events = generate()
    path = Path(arguments.output)
    path.write_text(''.join(json.dumps(event, sort_keys=True) + '\n' for event in events),
                    encoding='utf-8')
    print(f'{path}: {len(events)} synthetic events, {path.stat().st_size} bytes')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
