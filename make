#!/bin/bash
if [[ $# -eq 0 ]] ; then
    ruby make.rb hollywood.z3
    #ruby make.rb etude.z5
    exit 0
fi

ruby make.rb $@
