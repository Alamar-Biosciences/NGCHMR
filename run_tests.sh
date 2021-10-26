#!/usr/bin/env bash
# Run test for NGCHR algorithm. Return 0 if pass, 1 otherwise

set -e; #terminate script if any subscript returns an error

# Test 1
R --no-save < main.r &
PID=$!
sleep 5

cmd=`curl --data-binary @test_data.txt http://localhost:8080/curvefit`
cmd=`R --no-save < api_test.R`

echo "$cmd"
if [[ $cmd == *"Wrote results to"* ]]; then
  echo "Test succesful!...."
else
  exit(1)
fi

# Clean up
kill $PID;
