#!/bin/bash

URL=$(curl -s -F "file=@\"$1\";filename=.png" 'https://x0.at')
echo $URL | wl-copy
notify-send " $URL"
