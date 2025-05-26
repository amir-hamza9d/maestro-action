#!/bin/bash

# -----------------------------------------------------------------------
# This script reads a list of failed Maestro flow files and executes each
# one individually using 'maestro record'. It captures the results of each
# execution and provides detailed logging of successes and failures.
# -----------------------------------------------------------------------

# Enable strict error handling
set -uo pipefail

# Configuration
APP_ID=pdfreader.pdfviewer.officetool.pdfscanner
MAESTRO_BIN="$HOME/.maestro/bin/maestro"
FAILED_FLOWS_FILE="failed_tests.txt"
REPORT_DIR="artifacts"
TOTAL_SUCCESS=0
TOTAL_FAILURES=0
FAILED_FLOWS=()

# Check if the failed flows file exists and is not empty
if [ ! -s "$FAILED_FLOWS_FILE" ]; then
  echo "ℹ️ No failed tests to run. Exiting."
  exit 0
fi

# Create reports directory if it doesn't exist
mkdir -p "$REPORT_DIR"

# Function to start screen recording
start_recording() {
  echo "ℹ️ Starting screen recording..."
  $ANDROID_HOME/platform-tools/adb shell screenrecord /sdcard/video_record.mp4 &
  RECORD_PID=$!
  sleep 2  # Give screenrecord some time to start
}

# Function to stop recording and save artifacts
save_failure_artifacts() {
  local flow_name=$1
  local timestamp=$(date +"%Y%m%d_%H%M%S")
  local safe_flow_name=$(echo "$flow_name" | sed 's/[^a-zA-Z0-9]/_/g')

  # Stop recording and save video
  if [ -n "${RECORD_PID:-}" ]; then
    echo "ℹ️ Stopping screen recording..."
    kill -SIGINT "$RECORD_PID" || true
    sleep 2

    # Save video
    echo "ℹ️ Saving video recording for failed test..."
    $ANDROID_HOME/platform-tools/adb pull /sdcard/video_record.mp4 "$REPORT_DIR/failure_${safe_flow_name}_${timestamp}.mp4" || true
    $ANDROID_HOME/platform-tools/adb shell rm /sdcard/video_record.mp4 || true
  fi

  # Save screenshot
  echo "ℹ️ Taking screenshot for failed test..."
  $ANDROID_HOME/platform-tools/adb shell screencap -p /sdcard/failure_img.png
  $ANDROID_HOME/platform-tools/adb pull /sdcard/failure_img.png "$REPORT_DIR/failure_${safe_flow_name}_${timestamp}.png" || true
  $ANDROID_HOME/platform-tools/adb shell rm /sdcard/failure_img.png || true
}

# Count and print the number of failed tests
FAILED_COUNT=$(grep -v "^$" "$FAILED_FLOWS_FILE" | wc -l)
echo "ℹ️ Found $FAILED_COUNT failed tests to retry."

# Debug: Print all flows that will be run
echo "ℹ️ Tests that will be run:"
grep -v "^$" "$FAILED_FLOWS_FILE" | cat -n

# Process each failed test individually
while IFS= read -r flow_path || [ -n "$flow_path" ]; do
  # Skip empty lines
  if [ -z "$flow_path" ]; then
    continue
  fi

  # Extract flow name for logging
  flow_name=$(basename "$flow_path")

  echo "========================================================"
  echo "ℹ️ Executing flow: $flow_name"
  echo "========================================================"

  # Start recording for this specific test
  start_recording

  # Create a timestamp for this run
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

  # Execute the flow using maestro record
  # Note: We use eval with quoted variables to handle paths with spaces
  if eval "$MAESTRO_BIN record \"$flow_path\" --env=APP_ID=\"$APP_ID\""; then
    echo "✅ Flow passed: $flow_name"
    TOTAL_SUCCESS=$((TOTAL_SUCCESS + 1))

    # Just kill recording process without saving for successful tests
    if [ -n "${RECORD_PID:-}" ]; then
      kill -SIGINT "$RECORD_PID" || true
      sleep 2
      $ANDROID_HOME/platform-tools/adb shell rm /sdcard/video_record.mp4 || true
    fi
  else
    echo "❌ Flow failed: $flow_name"
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
    FAILED_FLOWS+=("$flow_path")

    # Save artifacts for this failed test
    save_failure_artifacts "$flow_name"

    # Start a new recording for the next test
    start_recording
  fi

  echo ""
  echo "ℹ️ Progress: $((TOTAL_SUCCESS + TOTAL_FAILURES))/$FAILED_COUNT completed"
  echo ""

  # Small delay between tests to ensure device is ready
  sleep 2

done < "$FAILED_FLOWS_FILE"

# Summary report
echo "========================================================"
echo "ℹ️ Execution Summary"
echo "========================================================"
echo "✅ Successful flows: $TOTAL_SUCCESS"
echo "❌ Failed flows: $TOTAL_FAILURES"
echo "ℹ️ Total flows processed: $((TOTAL_SUCCESS + TOTAL_FAILURES))"

# If there were failures, list them
if [ $TOTAL_FAILURES -gt 0 ]; then
  echo ""
  echo "❌ The following flows failed:"
  for failed_flow in "${FAILED_FLOWS[@]}"; do
    echo "   - $failed_flow"
  done

  # Exit with failure code
  echo ""
  echo "❌ Some flows are still failing. Marking job as failed."
  exit 1
else
  echo ""
  echo "✅ All flows passed successfully!"
  exit 0
fi

echo "ℹ️ Retry of failed tests completed. Check reports and artifacts in $REPORT_DIR directory."
