#!/usr/bin/env bash
# Run test for NGCHR algorithm. Return 0 if pass, 1 otherwise

set -e; #terminate script if any subscript returns an error

# Test 1
R --no-save < main.R &
PID=$!
trap "kill $PID" EXIT;
sleep 5

#cmd=`R --no-save < api_test.R`
#cmd=`curl -v --form "data=@test_data.txt" --form "bcodeA=@bcodeA.txt" --form "bcodeB=@bcodeB.txt" http://localhost:8000/ngchm -o out1.ngchm` ;
cmd=`curl -v --form "data=@out_seqRepP.xml" --form "bcodeA=@20220325_BarcodeA.txt" --form "bcodeB=@20220325_BarcodeB.txt" http://localhost:8000/ngchm -o out1.ngchm`;
if (( `stat -c%s out1.ngchm` < 1024 )); then
  exit 1
fi
echo "$cmd"
