#!/usr/bin/env bash


# From https://e.printstacktrace.blog/merging-json-files-recursively-in-the-command-line/

set -euo pipefail

if [ $# -eq 0 ]
then
  echo "USAGE : $(basename $0) [args...]"
  exit 0
fi

jq -s 'def deepmerge(a;b):
  reduce b[] as $item (a;
    reduce ($item | keys_unsorted[]) as $key (.;
      $item[$key] as $val | ($val | type) as $type | .[$key] = if ($type == "object") then
        deepmerge({}; [if .[$key] == null then {} else .[$key] end, $val])
      elif ($type == "array") then
        (.[$key] + $val | unique)
      else
        $val
      end)
    );
  deepmerge({}; .)' "${@}"
