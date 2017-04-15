#!/bin/bash

for I in `ls *pdf`; 
do
	gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dBATCH  -dQUIET -sOutputFile=compressed_$I $I;
done

