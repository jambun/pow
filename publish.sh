#!/bin/sh

rsync -avz html/img hudmol.com:/home/james/public_html/pow
rsync -avz html/maps hudmol.com:/home/james/public_html/pow

scp $@ hudmol.com:/home/james/public_html/pow/

echo https://james.whaite.com/pow/`basename $@` | tr -d '\n' | pbcopy

echo https://james.whaite.com/pow/`basename $@`
