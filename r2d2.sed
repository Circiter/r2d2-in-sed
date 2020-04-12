#!/bin/sed -Enf

# r2d2 voice in sed. :)

# Usage example: cat example.script | ./r2d2.sed | cat > /dev/dsp

# (c) Written by Circiter (mailto:xcirciter@gmail.com).
# License: MIT.

# Available at https://github.com/Circiter/r2d2-in-sed

:read $!{N; bread}

s/\n//g

s/$/@00000000100000000/ # Default seed for the PRNG code.

:next_command
    /^tone/ {
        s/^[^ ]* //;
        s/^([^ ]*) ([^ ;]*);/f1=\1; f2=\1; time=\2;/
        bplay_tone
    }

    /^buzz/ {
        s/^[^ ]* //;
        s/^([^ ;]*);/f1=1111111; f2=1111111; time=\1;/
        bplay_tone
    }

    /^glissando / {
        s/^[^ ]* //;
        s/^([^ ]*) ([^ ]*) ([^ ]*) ([^ ;]*);/dir=\1; f1=\2; f2=\3; time=\4;/
        bplay_tone
    }

    /^random/ { # Random note.
        s/^[^ ]* //;
        s/^([^ ]*) ([^ ]*) ([^ ;]*);/f1=\1; f2=\2; time=\2; dur=\3; note=true; number=;/

        brandom_generator

        :return_point

        s/ready=[^;]*;(.*)time=[^;]*;(.*)note=[^;]*;/\1\2/
        s/dur=/time=/

        # Keep incrementing the f1 until it reaches the
        # f2 or until we get a 0 after a "coin-toss".
        :increment
            :digit_replacement s/(f1=[01]*)1(_*;)/\1_\2/; tdigit_replacement
            s/f1=(_*;)/f1=1\1/
            s/(f1=[01]*)0(_*;)/\11\2/
            s/_/0/g
            s/number=[01]/number=/
            /number=1/ {
                /f1=([^;]*);.*f2=\1;/! bincrement
            }

        s/f1=([^;]*)(;.*f2=)[^;]*;/f1=\1\2\1;/ # Ensure f1==f2.

        bplay_tone
    }

    /^silence/ {
        s/^[^ ]* //;
        s/^([^ ;]*);/f1=0; f2=0; time=\1;/
        bplay_tone
    }

    /^noise/ {
        s/^[^ ]* //;
        s/^([^ ;]*);/time=\1;/
        brandom_generator
    }

    /^seed/ {
        s/^[^ ]* //;
        h; x; s/^([^ ;]*);.*$/\1/; x
        s/^[^ ;]*;//
        bprepare_for_next_command
    }

q

:play_tone
    # Prefix: f1=initial_frequency; f2=final_frequency; time=duration;

    s/f1=([^ ]*);/f0=\1; f1=\1;/
    s/time=([^ ]*);/dur=\1; time=\1;/

    # Prefix: frequency current_frequency final_frequency working_duration duration;

    # N.B., zero frequency.
    /f0=0;/ {s/f0=0;//; s/$/\n--------/; bsilence}

    s/$/\n/
    :decrement # Decrement f0.
        :digit s/(f0=[01]*)0(_*;)/\1_\2/; tdigit
        s/(f0=[01]*)1(_*;)/\10\2/
        s/_/1/g
        s/\n~*$/&~/
        s/f0=0([01])/f0=\1/
        /f0=0;/!bdecrement
    s/f0=0;[ ]*([^ ])/\1/

    s/\n[^\n]*$/&&/
    :dash_replace s/~(-*)$/-\1/; tdash_replace
    s/\n([^\n]*)$/\1/

    :silence

    # Pattern space:
    # current_frequency final_frequency working_duration duration;other_commands\nwaveform

    h
    # Remove the unecessary data from the hold space.
    x; s/^.*\n([^\n]*)$/\1/; y/-/\n/; x

    # Hold space: waveform.

    # Well, now we have one period of a square wave,
    # so play it enough times.

    s/^[^\n]*\n/&>/ # Add a marker just before the waveform.

    :one_period
        x; p; x # Output at least one period.

        :one_sample
            # Move the marker to the right,
            # one character at a time.
            s/>([^\n])/\1>/

            :dur_digit_replace s/(dur=[01]*)0(_*;)/\1_\2/; tdur_digit_replace
            s/(dur=[01]*)1(_*;)/\10\2/
            s/_/1/g
            s/dur=0([01]+;)/dur=\1/
            /dur=0;/ bchange_frequency
            />$/! bone_sample

        # Reinitialize the > marker.
        s/>//; s/^[^\n]*\n/&>/

        bone_period

    :change_frequency

    # Leave only the necessary information.
    s/\n.*$//
    s/dur=[01]*;[ ]*([^ ])/\1/

    # Decrement or increment f1.
    /dir=down/ {
        :down_digit_replace s/(f1=[01]*)0(_*;)/\1_\2/; tdown_digit_replace
        s/(f1=[01]*)1(_*;)/\10\2/
        s/_/1/g
        s/f1=0([01]+;)/f1=\1/
    }
    /dir=up/ {
        :up_digit_replace s/(f1=[01]*)1(_*;)/\1_\2/; tup_digit_replace
        s/f1=(_*;)/f1=1\1/
        s/(f1=[01]*)0(_*;)/\11\2/
        s/_/0/g
    }

    # Compare f1 and f2.
    /f1=([01]*);.*f2=\1;/! bplay_tone

bprepare_for_next_command

:random_generator
    # Rule 30 automaton.

    h; x; s/^.*@//

    # FIXME: Buffer underrun?
    # But "echo ... | ./r2d2.sed | cat > /dev/dsp" works...

    # Hold space: seed.

    :next_generation
        s/^(.)(.*)(.)$/>\3\1\2\3\1/ # Boundary conditions (wrap-around).

        :update
            # Lookup table in the format {<bit_number>=<bit>;}*, where each
            # bit is taken from the binary expansion of the rule number.
            s/$/\n000=0;001=1;010=1;011=1;100=1;101=0;110=0;111=0/

            # Hold space: growing_generation>old_generation\nlookup_table.
            # Append a next bit using the lookup table.
            s/^([^>]*)>(...)([^\n]*\n).*\2=(.)/\1\4>\2\3/
            s/\n.*$//

            s/>./>/ # Move the pointer (truncating the old generation).
            # Hold space: growing_generation_updated>old_generation_truncated.

            />$/! bupdate # Move the pointer as far as we can.

            s/>//

            # Wait /^1/ then begin to count (decrement
            # the time parameter in pattern space).
            /^1/ {x; /ready=true/! s/^/ready=true; /; x}
            x
            /ready=true/ {
                :dec_noise_timer s/(time=[01]*)0(_*;)/\1_\2/; tdec_noise_timer
                s/(time=[01]*)1(_*;)/\10\2/
                s/_/1/g
                s/time=0([01]+;)/time=\1/
                /time=0;/ bprepare_for_next_command
                /note=true/! {x; y/10/~\n/; p; y/~\n/10/; x}
                /note=true/ {
                    # Extract the center element.
                    x; s/^/>/; s/$/</
                    :to_center
                        s/>(.)/\1>/
                        s/(.)</<\1/
                        />.*</ bto_center
                    /<>/ s/(.)</<\1/
                    /<0>/ {x; s/(number=[01]*);/\10;/; x}
                    /<1>/ {x; s/(number=[01]*);/\11;/; x}
                    s/>//; s/<//; x
                }
            }
            x
            bnext_generation
    x

:prepare_for_next_command
    /note=true/ breturn_point
    # Leave only the commands.
    s/[^ ;=]*=[^ ;]*;//g
    :remove_white s/^ //; /^ / bremove_white
    /^@/! bnext_command
