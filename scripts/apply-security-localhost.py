#!/usr/bin/env python3
"""Bind published Docker ports to 127.0.0.1. Run on the VPS as pawel."""
from pathlib import Path

REPLACEMENTS = [
    ('/home/pawel/stacks/test-postgres/docker-compose.yml', '"5433:5432"', '"127.0.0.1:5433:5432"'),
    ('/home/pawel/stacks/qdrant/docker-compose.yml', '"6333:6333"', '"127.0.0.1:6333:6333"'),
    ('/home/pawel/stacks/qdrant/docker-compose.yml', '"6334:6334"', '"127.0.0.1:6334:6334"'),
    ('/home/pawel/stacks/minio/docker-compose.yml', '"9100:9000"', '"127.0.0.1:9100:9000"'),
    ('/home/pawel/stacks/minio/docker-compose.yml', '"9101:9001"', '"127.0.0.1:9101:9001"'),
    ('/home/pawel/stacks/portainer/docker-compose.yml', '"9000:9000"', '"127.0.0.1:9000:9000"'),
    ('/home/pawel/stacks/n8n/docker-compose.yml', '"5678:5678"', '"127.0.0.1:5678:5678"'),
    ('/home/pawel/stacks/nginx-proxy-manager/docker-compose.yml', '"81:81"', '"127.0.0.1:81:81"'),
    ('/home/pawel/stacks/db/docker-compose.yml', '"5050:80"', '"127.0.0.1:5050:80"'),
    ('/home/pawel/stacks/nc/docker-compose.yml', '"5432:5432"', '"127.0.0.1:5432:5432"'),
    ('/home/pawel/stacks/nc/docker-compose.yml', '"8000:8000"', '"127.0.0.1:8000:8000"'),
    ('/home/pawel/stacks/nc/docker-compose.yml', '"5555:5555"', '"127.0.0.1:5555:5555"'),
    ('/home/pawel/apps/nc/docker-compose/docker-compose.blue-green.yml', '"8000:8000"', '"127.0.0.1:8000:8000"'),
    ('/home/pawel/apps/nc/docker-compose/docker-compose.blue-green.yml', '"8001:8000"', '"127.0.0.1:8001:8000"'),
    ('/home/pawel/apps/nc/docker-compose/docker-compose.blue-green.yml', '"5432:5432"', '"127.0.0.1:5432:5432"'),
    ('/home/pawel/apps/nc/docker-compose/docker-compose.blue-green.yml', '"5555:5555"', '"127.0.0.1:5555:5555"'),
]


def main() -> None:
    for raw_path, old, new in REPLACEMENTS:
        path = Path(raw_path)
        if not path.exists():
            print(f'MISS file {path}')
            continue
        text = path.read_text()
        if old not in text:
            if new in text:
                print(f'ALREADY {path}: {new}')
            else:
                print(f'MISS {path}: {old}')
            continue
        path.write_text(text.replace(old, new, 1))
        print(f'OK {path}: {old} -> {new}')

    # k3s nc-prod łączy się do Postgresa przez docker0, nie przez 127.0.0.1.
    nc = Path('/home/pawel/stacks/nc/docker-compose.yml')
    if nc.exists():
        text = nc.read_text()
        extra = '      - "172.17.0.1:5432:5432"\n'
        needle = '      - "127.0.0.1:5432:5432"\n'
        if extra in text:
            print(f'ALREADY {nc}: k3s 172.17.0.1:5432')
        elif needle in text:
            nc.write_text(text.replace(needle, needle + extra, 1))
            print(f'OK {nc}: added k3s 172.17.0.1:5432')
        else:
            print(f'MISS {nc}: {needle.strip()}')


if __name__ == '__main__':
    main()
