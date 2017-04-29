#!/bin/bash

MUSIC_ROOT="/home/pi/Radio/Music"
PIFM_BINARY="fm_transmitter"
PIFM_FREQUENCY=103.3
LOG_ROOT="/home/pi/Radio/Logs"
SHUFFLE="true" # true | false
WHITELIST="3gp|aac|flac|m4a|m4p|mmf|mp3|ogg|vox|wav|wma"

#####################

LOG="$LOG_ROOT/pifm.log"
#mkdir -p "$LOG_ROOT"

TEMP_FILES_PREFIX='pifm.radio.tempfile'
TEMP_FILES_PATTERN="$TEMP_FILES_PREFIX.XXXXX"

{
    echo; echo -n "script $0 starting at"; date
    echo "MUSIC_ROOT: $MUSIC_ROOT"

    iteration=0
    while [ 1 ] # run forever...
    do
        iteration=$(( $iteration + 1 ))
        echo -n "start with iteration $iteration of playing all files in $MUSIC_ROOT at "; date
        rm -vf "/tmp/$TEMP_FILES_PREFIX."*

        # Collecting the songs in the specified dir

        songListFile="$( mktemp "$TEMP_FILES_PATTERN" )"

        find "$MUSIC_ROOT" -type f -follow \
        | grep -iE ".*\.($WHITELIST)$" \
        | sort \
        > "$songListFile"

        songCount="$( wc -l "$songListFile" | grep -Eo '^[0-9]*' )"

        if [ "x" = "x$songCount" ]; then echo "FATAL: no songs could be found in $MUSIC_ROOT"; exit 2; fi
        if [ $songCount -lt 1 ];    then echo "FATAL: no songs could be found in $MUSIC_ROOT"; exit 2; fi

        # Generate a playlist from the results

        playlist="$( mktemp "$TEMP_FILES_PATTERN" )"
        if [ $SHUFFLE = "true" ]; then 
            # prefix each line with random number, sort numerically and cut of leading number ;-)        
            cat "$songListFile" \
            | while read song; do echo "${RANDOM} $song"; done \
            | sort -n \
            | cut -d " " -f 2- \
            | while read song; do echo "${RANDOM} $song"; done \
            | sort -n \
            | cut -d " " -f 2- \
            > "$playlist"
        else
            cp "$songListFile" "$playlist"
        fi

        # Play each song from the playlist

        echo "will now air $songCount songs of $playlist on frequency $PIFM_FREQUENCY, enjoy!"
        cat "$playlist" \
        | while read song
        do
            # simple version: take 1st audio channel:
            #
            # command="avconv -v fatal -i '$song' -ac 1 -ar 22050 -b 352k -f wav - | '$PIFM_BINARY' - $PIFM_FREQUENCY"

            # extended version: merge audio channels:
            #
            # merge the channesl of the song to one mono channel, write to stdout:
            #     sox '$song' -t wav - channels 1
            #
            # read mono audio from stdin, convert into pifm format and write to stdout:
            #     avconv -v fatal -i pipe:0 -ac 1 -ar 22050 -b 352k -f wav -
            #
            # read compatible audio data from stdin and play with pifm at specified frequency:
            #     '$PIFM_BINARY' - $PIFM_FREQUENCY 
            command="sox '$song' -r 22050 -c 1 -b 16 -t wav - |sudo ./'$PIFM_BINARY' -f $PIFM_FREQUENCY -" 
			# sox /home/pi/Radio/Music/sound.wav -r 22050 -c 1 -b 16 -t wav - | sudo ./fm_transmitter -f 103.3 -
			# command="sox '$song' -t mp3 - channels 1 | avconv -v fatal -i pipe:0 -ac 1 -ar 22050 -b 352k -f wav - | '$PIFM_BINARY' - $PIFM_FREQUENCY"
			# sox song.mp3 -r 22050 -c 1 -b 16 -t wav - | sudo ./fm_transmitter -f 103.3 -



            echo "$command # $( date )"
            bash -c "$command"

        done # with playlist
        echo -n "done with iteration $iteration at "; date

    done # with endless loop :-)

} 2>&1 | tee -a "$LOG"