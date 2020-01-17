#!/bin/bash

# used by docker-sync
export DOCKER_HOST=tcp://127.0.0.1:2375

#################################################################
# If not running interactively, do some settings

if [[ ! -z "$PS1" ]]; then
    # This shell is interactive
    source "${HOME}/.bashrc"
fi

