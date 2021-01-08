#!/bin/sh
python -m hjson.tool -c | jq "${1} = \"${2}\""
