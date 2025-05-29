#!/bin/bash

# -----------------------------------------------------------------------
# This script reads a list of failed Maestro flow files and executes each
# one individually using 'maestro test'. It captures the results of each
# execution and provides detailed logging of successes and failures.
# -----------------------------------------------------------------------

# Enable strict error handling
set -euo pipefail

# Configuration
APP_ID=pdfreader.pdfviewer.officetool.pdfscanner
MAESTRO_BIN="$HOME/.maestro/bin/maestro"
FAILED_FLOWS_FILE="failed_tests.txt"
REPORT_DIR="artifacts"
TOTAL_SUCCESS=0
TOTAL_FAILURES=0
FAILED_FLOWS=()

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  echo "ℹ️ Loading environment variables from .env file"
  set -a  # automatically export all variables
  source .env
  set +a  # turn off automatic export
fi

# Set Maestro logging pattern if not already set
if [ -z "${MAESTRO_CLI_LOG_PATTERN_CONSOLE:-}" ]; then
  export MAESTRO_CLI_LOG_PATTERN_CONSOLE="%highlight([%5level]) %msg%n"
fi

# Check if the failed flows file exists and is not empty
if [ ! -s "$FAILED_FLOWS_FILE" ]; then
  echo ""
  echo "ℹ️ No failed tests to run. Exiting."
  exit 0
fi

echo ""

# Create reports directory if it doesn't exist
mkdir -p "$REPORT_DIR"
echo "📊 Reports will be saved to: $REPORT_DIR"

# Read all failed test paths into an array
FAILED_TEST_PATHS=()
while IFS= read -r flow_path || [ -n "$flow_path" ]; do
  # Skip empty lines
  if [ -z "$flow_path" ]; then
    continue
  fi
  # Add to array
  FAILED_TEST_PATHS+=("$flow_path")
done < "$FAILED_FLOWS_FILE"

# Count and print the number of failed tests
FAILED_COUNT=${#FAILED_TEST_PATHS[@]}
echo "ℹ️ Found $FAILED_COUNT failed tests to retry."

echo "=== 🔄 Retrying Failed Tests ==="

# Debug: Print all flows that will be run
echo "ℹ️ Tests that will be run:"
for i in "${!FAILED_TEST_PATHS[@]}"; do
  echo "   $((i+1)). ${FAILED_TEST_PATHS[i]}"
done

# Create a timestamp for this run
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
echo "⏱️  Test started at: $(date)"
echo "🧪 Running all failed tests together..."

# Execute all failed tests together in a single maestro test command
if $MAESTRO_BIN test "${FAILED_TEST_PATHS[@]}" --env=APP_ID="$APP_ID" --format=html --output "$REPORT_DIR/retry_failed_tests_${TIMESTAMP}.html"; then
  echo "✅ All failed tests passed successfully!"
  echo "📊 Full report available at: $REPORT_DIR/retry_failed_tests_${TIMESTAMP}.html"
  TOTAL_SUCCESS=$FAILED_COUNT
  TOTAL_FAILURES=0
else
  echo "❌ Some tests are still failing."
  echo "📊 Full report available at: $REPORT_DIR/retry_failed_tests_${TIMESTAMP}.html"
  echo "🔍 Check the report for details on which specific tests failed"
  TOTAL_SUCCESS=0
  TOTAL_FAILURES=$FAILED_COUNT
fi

echo "⏱️  Test finished at: $(date)"

# Summary report
echo "========================================================"
echo "ℹ️ Execution Summary"
echo "========================================================"
echo "ℹ️ Total flows processed: $FAILED_COUNT"

# Exit based on test results
if [ $TOTAL_FAILURES -gt 0 ]; then
  echo "❌ Some flows are still failing."
  echo "🔍 Check the detailed report at: $REPORT_DIR/retry_failed_tests_${TIMESTAMP}.html"
  echo "❌ Marking job as failed."
  exit 1
else
  echo "✅ All previously failed flows now pass!"
  echo "📊 Detailed report available at: $REPORT_DIR/retry_failed_tests_${TIMESTAMP}.html"
  exit 0
fi




****