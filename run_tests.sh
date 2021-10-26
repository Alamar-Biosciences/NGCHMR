#!/usr/bin/env bash
# Run test for NGCHR algorithm. Return 0 if pass, 1 otherwise

set -e; #terminate script if any subscript returns an error

# Test 1
R --no-save < main.R &
PID=$!
sleep 5

cmd=`R --no-save < api_test.R`

echo "$cmd"
if [[ $cmd == *"Wrote results to"* ]]; then
  echo "Test succesful!...."
else
  exit(1)
fi

# Clean up
kill $PID;
