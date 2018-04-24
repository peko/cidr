#!/bin/bash
make && ./hilbert | ffmpeg -hide_banner -f rawvideo -s 256x256 -pixel_format gray -i - -y out.png
