#!/bin/sh

echo 'This is a sample script!'
NEWVAR=2
VAR=1
echo variables set
while [[ $VAR == 1 ]]
do echo VAR is $VAR
    VAR=0
done
echo The script is over.
