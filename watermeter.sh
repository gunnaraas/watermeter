#!/bin/bash

# requires that the following go programs are installed in ~/go/bin
# - go install github.com/abaker/stdout_httpd@latest
# - go install github.com/bemasher/rtlamr@latest

# requires that rtl_tcp is installed on Raspberry Pi, use these instructions:
# https://gist.github.com/floehopper/99a0c8931f9d779b0998

rtl_tcp & sleep 5
./go/bin/rtlamr -msgtype=r900 -centerfreq=912000000 -filterid=$WaterMeterSerialNumber -format=json |
  jq --unbuffered -c '. |= del(.Message) + .Message' |
  ./go/bin/stdout_httpd -port 8080
