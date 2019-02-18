#!/bin/bash
while getopts ":-:" optchar; do
    [[ "${optchar}" == "-" ]] || continue
    echo "${OPTARG}"
    case "${OPTARG}" in
        datadir=* )
            DATA_DIR=${OPTARG#*=}
            ;;
        restore_cmd=* )
            RESTORE_CMD=${OPTARG#*=}
            ;;
    esac
done

[[ -z $DATA_DIR ]] && exit 1

$RESTORE_CMD $DATA_DIR LATEST