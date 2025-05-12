#!/bin/bash

set -euo pipefail

# Configuration
APP_ID=pdfreader.pdfviewer.officetool.pdfscanner
MAESTRO_BIN="$HOME/.maestro/bin/maestro"
FAILED_FLOWS_FILE="failed_tests.txt"
REPORT_DIR="artifacts"

# Check if the failed flows file exists and is not empty
if [ ! -s "$FAILED_FLOWS_FILE" ]; then
  echo "No failed tests to run. Exiting."
  exit 0
fi

# Create reports directory if it doesn't exist
mkdir -p "$REPORT_DIR"

# Function to start screen recording
start_recording() {
  echo "===Starting screen recording...==="
  $ANDROID_HOME/platform-tools/adb shell screenrecord /sdcard/video_record.mp4 &
  RECORD_PID=$!
  sleep 2  # Give screenrecord some time to start
}

# Function to stop recording and save artifacts
save_failure_artifacts() {
  local timestamp=$(date +"%Y%m%d_%H%M%S")

  # Stop recording and save video
  if [ -n "${RECORD_PID:-}" ]; then
    echo "Stopping screen recording..."
    kill -SIGINT "$RECORD_PID" || true
    sleep 2

    # Save video
    echo "Saving video recording for failed test..."
    $ANDROID_HOME/platform-tools/adb pull /sdcard/video_record.mp4 "$REPORT_DIR/failure_retry_${timestamp}.mp4" || true
    $ANDROID_HOME/platform-tools/adb shell rm /sdcard/video_record.mp4 || true
  fi

  # Save screenshot
  echo "Taking screenshot for failed test..."
  $ANDROID_HOME/platform-tools/adb shell screencap -p /sdcard/failure_img.png
  $ANDROID_HOME/platform-tools/adb pull /sdcard/failure_img.png "$REPORT_DIR/failure_retry_${timestamp}.png" || true
  $ANDROID_HOME/platform-tools/adb shell rm /sdcard/failure_img.png || true
}

# Count and print the number of failed tests
FAILED_COUNT=$(grep -v "^$" "$FAILED_FLOWS_FILE" | wc -l)
echo "Found $FAILED_COUNT failed tests to retry."

# Debug: Print all flows that will be run
echo "Tests that will be run:"
grep -v "^$" "$FAILED_FLOWS_FILE" | cat -n

# Start recording before tests
start_recording

# Run all failed tests in a single command
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
if $MAESTRO_BIN test $(grep -v "^$" "$FAILED_FLOWS_FILE") --env=APP_ID="$APP_ID" --format=html --output "$REPORT_DIR/retry_all_${TIMESTAMP}.html"; then
  echo "✅ All flows passed!"
  
  # Just kill recording process without saving
  if [ -n "${RECORD_PID:-}" ]; then
    kill -SIGINT "$RECORD_PID" || true
    sleep 2
    $ANDROID_HOME/platform-tools/adb shell rm /sdcard/video_record.mp4 || true
  fi
  exit 0
else
  echo "❌ Some flows are still failing"
  
  # Save artifacts for failed tests
  save_failure_artifacts
  
  # Explicitly exit with failure code
  echo "Tests failed even after retry. Marking job as failed."
  exit 1
fi

echo "Retry of failed tests completed. Check reports and artifacts in $REPORT_DIR directory."
