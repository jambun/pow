#!/bin/sh

rsync -avz html/img hudmol.com:/home/james/public_html/pow
rsync -avz html/maps hudmol.com:/home/james/public_html/pow

scp $@ hudmol.com:/home/james/public_html/pow/

