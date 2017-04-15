#! /bin/sh

for a in *.wav; do
    OUTF=${a%.wav}.mp3

		lame -V0 -b 320 "$a" "$OUTF"
    
		RESULT=$?
    if [ "$1" ] && [ "$1" = "-d" ] && [ $RESULT -eq 0 ]; then
      rm "$a"
    fi
done

