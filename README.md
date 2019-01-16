# Snake-in-a-day
Coding practice example of Snake, on the SAM Coupé

Actually I think this took a couple of hours one day, then a day off, and a final evening finishing it.  It's not the world's best code but there's plenty of comments for a beginner to follow along.

In addition to my code, the source includes SAMDOS2 binary (needed for loading of object file from the compiled diskimage).


COMPILING AND PLAYING

This version is compiled with PYZ80, a freely-available Z80 cross-assembler found at http://www.intensity.org.uk/samcoupe/pyz80.html. After installing PYZ80 you can compile the diskimage by running make_home.bat. You'll need to amend the filepaths in this file for your system.

It can be run in SimCoupe or ASCD, both up-to-date popular emulators for the original machine, from https://wwww.simcoupe.org/ and http://www.keprt.cz/sam/

This can be used on a real Sam by converting the diskimage to a floppy disk with SAMDisk by Simon Owen, available from http://simonowen.com/samdisk/
