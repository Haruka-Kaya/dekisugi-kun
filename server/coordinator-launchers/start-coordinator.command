#!/bin/sh
set -eu

launcher_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$launcher_directory/dekisugi-lan-coordinator" --host 0.0.0.0 --allow-lan
