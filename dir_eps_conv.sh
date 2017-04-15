#!/bin/bash
for I in `ls *eps`; do mv $I $I.OLD; eps2eps -dEmbedAllFonts=true $I.OLD $I; done
rm *.OLD
