#!/bin/csh -f

if (-e WORK) then
  rm -rf WORK
endif

##---- back up last run result and prpare run log directory

if (! -e ./bak) then
  mkdir bak
endif

if (-e ./log) then
  if (! -e ./bak/log_bak) then 
     mkdir ./bak/log_bak
  endif
  mv -f ./log/* ./bak/log_bak/
else
  mkdir log
endif

if (-e ./result) then
  if (! -e ./bak/result_bak) then
    mkdir ./bak/result_bak
  endif
  mv -f ./result/* ./bak/result_bak
else
  mkdir result
endif

if (-e ./db) then
  if (! -e ./bak/db_bak) then
     mkdir ./bak/db_bak
  endif
  mv -f ./db/* ./bak/db_bak
else
  mkdir db
endif

if (-e ./rpt) then
  if (! -e ./bak/rpt_bak) then
     mkdir ./bak/rpt_bak
  endif
  mv -f ./rpt/*  ./bak/rpt_bak
else
  mkdir rpt
endif

if (-e filenames.log) then
  mv filenames.log ./bak/filenames.log.bak
endif

if (-e command.log) then
  mv  command.log ./bak/command.log.bak
endif

if (-e dc_syn.log) then
  mv dc_syn.log ./bak/dc_syn.log.bak
endif


##-------------------##
##---  RUN DC -------##
##-------------------##

echo "-------------------------------------"
echo "--- Begin run DC --------------------"
echo "-------------------------------------"
echo "--- `date` --"
echo "-------------------------------------"

dc_shell-t -64 -f ./scr/main.tcl | tee dc_syn.log
#dc_shell-t

echo "-------------------------------------"
echo "--- End DC Conpile ------------------"
echo "-------------------------------------"
echo "--- `date` --"
echo "-------------------------------------"

