#!/bin/bash

function announce {
    >&2 echo -e "\e[33m$*\e[39m"
    if [[ ${PAUSE} = 1 ]]; then
        read
    fi
}

function run {
    >&2 echo -e "\e[34mRunning: \e[94m$*\e[39m"
    $*
}

function pause {
    >&2 echo -e "\e[34mDone\e[39m"
    if [[ ${PAUSE} = 1 ]]; then
        read
    fi
}

