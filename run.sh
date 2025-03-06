#!/bin/sh

runjdb(){
  ./sw-process-info |
    jq -c |
    dasel --read=json --write=toml |
    bat --language=toml
}

which jq    | fgrep -q jq    || exec ./sw-process-info
which dasel | fgrep -q dasel || exec ./sw-process-info
which bat   | fgrep -q bat   || exec ./sw-process-info

runjdb
