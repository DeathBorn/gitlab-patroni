#!/bin/bash
while getopts ":-:" optchar; do
    [[ "${optchar}" == "-" ]] || continue
    echo "${OPTARG}"
    case "${OPTARG}" in
        datadir=* )
            DATA_DIR=${OPTARG#*=}
            ;;
    esac
done

[[ -z $DATA_DIR ]] && exit 1

/usr/bin/envdir /etc/wal-e.d/env /opt/wal-e/bin/wal-e backup-fetch $DATA_DIR LATEST