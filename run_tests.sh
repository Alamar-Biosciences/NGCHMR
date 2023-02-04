#!/usr/bin/env bash
# Run test for NGCHR algorithm. Return 0 if pass, 1 otherwise

set -e; #terminate script if any subscript returns an error

# Set up the server for testing
PORT=8000
Rscript --vanilla main.R $PORT &
PID=$!
trap "kill $PID" EXIT;
sleep 5

# Test 1: plot IC data 
#cmd=`R --no-save < api_test.R`
#cmd=`curl -v --form "data=@test_data.txt" --form "bcodeA=@bcodeA.txt" --form "bcodeB=@bcodeB.txt" http://localhost:8000/ngchm -o out1.ngchm` ;
echo -e "\n\nRunning Test 1:";
cmd=`curl -v --form "data=@out_seqRepP.xml;type=text/xml" "http://localhost:$PORT/ngchm?method=IC" -o out1.ngchm`;
if (( `stat -c%s out1.ngchm` < 1024 )); then
  echo "Test 1 failed!";
  exit 1
fi

# Test 2: plot TC data 
echo -e "\n\nRunning Test 2:";
cmd=`curl -v --form "data=@out_seqRepP.xml;type=text/xml" "http://localhost:$PORT/ngchm?method=TC" -o out1.ngchm`;
if (( `stat -c%s out1.ngchm` < 1024 )); then
  echo "Test 2 failed!";
  exit 1
fi

# Test 3: plot IC data, replacement BarcodeA file
echo -e "\n\nRunning Test 3:";
cmd=`curl -v --form "data=@out_seqRepP.xml;type=text/xml" --form "bcodeA=@20220325_BarcodeA.txt;type=text/plain" "http://localhost:$PORT/ngchm?method=IC" -o out1.ngchm`;
if (( `stat -c%s out1.ngchm` < 1024 )); then
  echo "Test 3 failed!";
  exit 1
fi

# Test 4: plot IC data, replacement BarcodeB File
echo -e "\n\nRunning Test 4:";
cmd=`curl -v --form "data=@out_seqRepP.xml;type=text/xml" --form "bcodeB=@20220325_BarcodeB.txt;type=text/plain" "http://localhost:$PORT/ngchm?method=IC" -o out1.ngchm`;
if (( `stat -c%s out1.ngchm` < 1024 )); then
  echo "Test 4 failed!";
  exit 1
fi

# Test 5: plot IC data, replacement BarcodeA and BarcodeB File
echo -e "\n\nRunning Test 5:";
cmd=`curl -v --form "data=@out_seqRepP.xml;type=text/xml" --form "bcodeA=@20220325_BarcodeA.txt;type=text/plain" --form "bcodeB=@20220325_BarcodeB.txt;type=text/plain" http://localhost:$PORT/ngchm -o out1.ngchm`;
if (( `stat -c%s out1.ngchm` < 1024 )); then
  echo "Test 5 failed!";
  exit 1
fi
echo -e "\n\nTests Passed!"
