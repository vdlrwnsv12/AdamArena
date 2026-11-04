#!/usr/bin/env python3
"""Read-only, bounded RDAR segment collector for the H10 sleep scene.

No decompression, installation, network access, or game-file writes.
RDAR layouts: WolvenKit.RED4/Archive/IO/ArchiveReader.cs, main 6ab5da88.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import time
import zipfile

HEADER = struct.Struct('<IIQIQIQ')
INDEX = struct.Struct('<IIQIII')
ENTRY = struct.Struct('<QqIIIII20s')
SEGMENT = struct.Struct('<QII')
MAX_INDEX = 256 * 1024 * 1024
MAX_ASSET = 32 * 1024 * 1024
MAX_TOTAL = 128 * 1024 * 1024


def normalized(path):
    path = path.strip().lower().replace('/', '\\')
    while '\\\\' in path:
        path = path.replace('\\\\', '\\')
    return path


def fnv1a(path):
    value = 0xcbf29ce484222325
    for byte in path.encode('ascii'):
        value = ((value ^ byte) * 0x100000001b3) & 0xffffffffffffffff
    return value


def targets_from(path):
    result = {}
    for line in path.read_text(encoding='utf-8').splitlines():
        if not line.strip() or line.startswith('#'):
            continue
        name = normalized(line)
        for candidate in (name, 'base\\' + name):
            result[fnv1a(candidate)] = candidate
    return result


def read_exact(stream, size):
    data = stream.read(size)
    if len(data) != size:
        raise ValueError('truncated archive')
    return data


def read_matches(stream, file_size, targets):
    magic, version, index_pos, index_size, _, _, declared_size = HEADER.unpack(read_exact(stream, HEADER.size))
    if magic != 1380009042 or version != 12:
        raise ValueError('unsupported RDAR header/version')
    if index_pos < HEADER.size or index_size < INDEX.size or index_size > MAX_INDEX or index_pos + index_size > file_size:
        raise ValueError('invalid archive index bounds')
    if declared_size > file_size:
        raise ValueError('archive size is incomplete')
    stream.seek(index_pos)
    data = read_exact(stream, index_size)
    _, _, _, entries, segments, dependencies = INDEX.unpack_from(data)
    seg_base = INDEX.size + entries * ENTRY.size
    if seg_base + segments * SEGMENT.size + dependencies * 8 > len(data):
        raise ValueError('invalid archive table counts')
    matches = []
    for i in range(entries):
        row = ENTRY.unpack_from(data, INDEX.size + i * ENTRY.size)
        name_hash, timestamp, inline, start, end, dep_start, dep_end, sha1 = row
        if name_hash not in targets:
            continue
        if not (0 <= start < end <= segments) or end - start > 256 or not (0 <= dep_start <= dep_end <= dependencies):
            raise ValueError('invalid matching entry bounds')
        parts = []
        for j in range(start, end):
            offset, compressed, size = SEGMENT.unpack_from(data, seg_base + j * SEGMENT.size)
            if offset < HEADER.size or compressed <= 0 or size <= 0 or offset + compressed > file_size:
                raise ValueError('invalid matching segment bounds')
            parts.append((offset, compressed, size))
        if sum(p[1] for p in parts) > MAX_ASSET or sum(p[2] for p in parts) > MAX_ASSET:
            raise ValueError('matching asset exceeds 32 MiB limit')
        matches.append({'path': targets[name_hash], 'hash': str(name_hash), 'timestamp': timestamp,
                        'inline_segments': inline, 'sha1': sha1.hex(), 'parts': parts})
    return matches


def collect(game, output, targets):
    game = game.resolve()
    output = output.resolve()
    if output == game or game in output.parents:
        raise ValueError('output must be outside the game folder')
    archive_root = game / 'archive'
    if not archive_root.is_dir():
        raise ValueError('게임의 archive 폴더를 찾지 못했습니다.')
    archives = sorted(p for p in archive_root.rglob('*.archive')
                      if not p.is_symlink() and not any(s.lower() in ('mod', 'mods') for s in p.relative_to(archive_root).parts[:-1]))
    if not archives:
        raise ValueError('기본 게임 .archive 파일을 찾지 못했습니다.')
    manifest = {'format': 'adam-bed-rdar-segments-1', 'compressed_segments': True,
                'purpose': 'H10 native bed animation inspection', 'archives': [], 'assets': []}
    total = 0
    with zipfile.ZipFile(output, 'x', compression=zipfile.ZIP_STORED) as package:
        for i, archive in enumerate(archives):
            relative = str(archive.relative_to(archive_root))
            print('[%d/%d] %s' % (i + 1, len(archives), archive.name), flush=True)
            report = {'name': relative}
            try:
                if archive_root.resolve() not in archive.resolve().parents:
                    raise ValueError('archive resolves outside the game archive folder')
                with archive.open('rb') as stream:
                    matches = read_matches(stream, os.fstat(stream.fileno()).st_size, targets)
                    report['matching_entries'] = len(matches)
                    for match in matches:
                        asset = {k: v for k, v in match.items() if k != 'parts'}
                        asset.update(archive=relative, segments=[])
                        for j, (offset, compressed, size) in enumerate(match['parts']):
                            if total + compressed > MAX_TOTAL:
                                raise ValueError('collection exceeds the 128 MiB limit')
                            stream.seek(offset)
                            blob = read_exact(stream, compressed)
                            name = 'segments/%04d-%s-%03d.bin' % (i, match['hash'], j)
                            package.writestr(name, blob)
                            asset['segments'].append({'file': name, 'offset': offset, 'compressed_size': compressed,
                                                      'size': size, 'sha256': hashlib.sha256(blob).hexdigest()})
                            total += compressed
                        manifest['assets'].append(asset)
            except (OSError, ValueError, struct.error) as error:
                report['error'] = str(error)
            manifest['archives'].append(report)
        manifest['total_segment_bytes'] = total
        manifest['target_paths'] = sorted(targets.values())
        package.writestr('manifest.json', json.dumps(manifest, ensure_ascii=False, indent=2).encode('utf-8'))
    return manifest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--game', type=Path, default=Path.home() / 'Library/Application Support/Steam/steamapps/common/Cyberpunk 2077')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    kit = Path(__file__).resolve().parent.parent
    output = args.output or kit / ('bed-assets-' + time.strftime('%Y%m%d-%H%M%S') + '.zip')
    try:
        manifest = collect(args.game, output, targets_from(kit / 'tools/bed_asset_paths.txt'))
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print('수집 실패: %s' % error, file=sys.stderr)
        return 1
    print('\n침대 관련 파일 %d개를 복사했습니다. 게임 파일은 변경하지 않았습니다.' % len(manifest['assets']))
    print('이 채팅에 아래 파일을 첨부해 주세요:\n%s' % output)
    if not any(a['path'].endswith('mq000_01_apartment.scene') for a in manifest['assets']):
        print('주의: 기본 침대 장면이 발견되지 않았습니다. 결과 ZIP의 진단 기록을 확인해야 합니다.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
