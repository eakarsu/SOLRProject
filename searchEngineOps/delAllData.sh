#!/bin/bash
set -x #echo on

host=localhost
port=8080
webpath=migrossolr
corename=ProductsCoreOnlySanal
curl http://$host:$port/$webpath/$corename/update --data '<delete><query>*:*</query></delete>' -H 'Content-type:text/xml; charset=utf-8'
curl http://$host:$port/$webpath/$corename/update --data '<commit/>' -H 'Content-type:text/xml; charset=utf-8'

