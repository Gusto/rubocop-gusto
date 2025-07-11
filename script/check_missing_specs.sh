#!/bin/bash

for file in $(find lib/rubocop/cop -name "*.rb"); do
  spec_file="spec/rubocop/cop/${file#lib/rubocop/cop/}"
  spec_file="${spec_file%.rb}_spec.rb"
  if [ ! -f "$spec_file" ]; then
    echo "Missing spec file for:"
  fi
  echo "Checked file: $file"
done
echo 'Finished running checks for missing Rubocop specs'
