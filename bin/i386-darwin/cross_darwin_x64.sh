#!/bin/sh
# ###############################################
#               fpcup for darwin.
#             cross compile script.
# 

echo "Build cross compiler for Darwin x86_64"
echo

./fpcup_osx_x86 --ostarget="darwin" --cputarget="x86_64" --only="FPCCleanOnly,FPCBuildOnly"

# ./fpclazup_osx_x86 --ostarget="darwin" --cputarget="x86_64" --only="FPCCleanOnly,FPCBuildOnly"

echo
echo "Building cross compiler for Darwin x86_64 ready"

#
#           cross compile script ready.
# 
# ###############################################
