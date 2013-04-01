#!/bin/sh
echo on
echo $PWD
EJAB_SRCS=`$PWD/../ejabberd-dev/trunk/src/*.erl`
EJAB_HDR=`$PWD/../ejabberd-dev/trunk/*.hrl`

echo $EJAB_SRCS
echo $EJAB_HDR

cp -rf --verbose $EJAB_HDR `$PWD/src/.` 
cp -rf --verbose $EJAB_SRCS `$PWD/src/.`

