#!/bin/bash

# Still has to copy the file, but at least encapsulates it
# The named-pipe version would lock itself up, even with extra buffering

if [ "$TMPDIR_t" == "" ] ; then
    TMPDIR_t=/tmp
fi
#TMPFILE="$TMPDIR_t/$(basename $0).$$.tmp"
TMPFILE=`mktemp`
#if [ -f "$TMPFILE" ] ; then
#    rm $TMPFILE
#fi
#mkfifo $TMPFILE

# if no params, cat or cut will take stdin
# cat $1 > $TMPFILE
cut -f1-3 $1 > $TMPFILE

# now two things can read the temp file at once
bedops --ec -m $TMPFILE | $SCRIPT_DIR/expandBedRangesToBases.pl \
    | bedmap --delim '\t' --ec --echo --bases --bases - $TMPFILE 

rm $TMPFILE
exit

# \
#cat $1 \
#    | teepipe.pl \
#    | dd bs=500M \
#    | bedmap --delim '\t' --ec --echo --bases --bases $TMPFILE -

#cat $1 | tee $TMPFILE | bedops --ec -m - | expandBedRangesToBases.pl \
    #| bedmap --delim '\t' --ec --echo --bases --bases - $TMPFILE 


