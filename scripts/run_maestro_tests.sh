#!/bin/bash

set -euo pipefail
set -x  # Print all commands for visibility

# Configuration
TMP_FILE=_fail_process_local
APP_ID=pdfreader.pdfviewer.officetool.pdfscanner
MAESTRO_BIN="$HOME/.maestro/bin/maestro"
MAX_RETRIES=2
TEST_SUCCESS=false
MAESTRO_TEST_DIR="flows"  # Directory containing your test flows

# Create output directory for reports and artifacts if it doesn't exist
REPORT_DIR="artifacts"

# Function to start screen recording
start_recording() {
  echo "Starting screen recording..."
  $ANDROID_HOME/platform-tools/adb shell screenrecord /sdcard/video_record.mp4 &
  RECORD_PID=$!
  sleep 2  # Give screenrecord some time to start
}

# Function to stop recording without saving
stop_recording() {
  if [ -n "${RECORD_PID:-}" ]; then
    echo "Stopping screen recording without saving..."
    kill -SIGINT "$RECORD_PID" || true
    sleep 2
    $ANDROID_HOME/platform-tools/adb shell rm /sdcard/video_record.mp4 || true
    unset RECORD_PID
  fi
}

# Function to save artifacts for failed tests in the final attempt
save_final_failure_artifacts() {
  local timestamp=$(date +"%Y%m%d_%H%M%S")

  # Stop recording and save video
  if [ -n "${RECORD_PID:-}" ]; then
    echo "Stopping screen recording..."
    kill -SIGINT "$RECORD_PID" || true
    sleep 2

    # Save video
    echo "Saving video recording for final failed attempt..."
    $ANDROID_HOME/platform-tools/adb pull /sdcard/video_record.mp4 "$REPORT_DIR/final_failure_recording_${timestamp}.mp4" || true
    $ANDROID_HOME/platform-tools/adb shell rm /sdcard/video_record.mp4 || true
  fi

  # Save screenshot
  echo "Taking screenshot for final failed attempt..."
  $ANDROID_HOME/platform-tools/adb shell screencap -p /sdcard/failure_img.png
  $ANDROID_HOME/platform-tools/adb pull /sdcard/failure_img.png "$REPORT_DIR/final_failure_screenshot_${timestamp}.png" || true
  $ANDROID_HOME/platform-tools/adb shell rm /sdcard/failure_img.png || true
}

# Start initial recording
start_recording

echo "===== Starting Maestro Tests ====="
echo "App ID: $APP_ID"
echo "Test Directory: $MAESTRO_TEST_DIR"

# Run Maestro tests with retries
for i in $(seq 1 $MAX_RETRIES); do
  echo "===== Run E2E Attempt: $i ====="
  if $MAESTRO_BIN test "$MAESTRO_TEST_DIR/" --env=APP_ID="$APP_ID" --format=html --output "$REPORT_DIR/report-$i-attempt.html"; then
    TEST_SUCCESS=true
    echo "✅ Test succeeded on attempt $i"
    break
  else
    echo "❌ Attempt $i failed"

    # If this is the last attempt, save artifacts
    if [ $i -eq $MAX_RETRIES ]; then
      echo "Final attempt failed. Saving artifacts..."
      save_final_failure_artifacts
    else
      # Otherwise, just stop the recording without saving
      stop_recording

      # Start a new recording for the next attempt
      start_recording

      echo "Retrying in $((i * 10)) seconds..."
      sleep $((i * 10))  # Increasing delay before retry
    fi
  fi
done

# If tests were successful, stop recording without saving artifacts
if [ "$TEST_SUCCESS" = true ]; then
  # Just stop the recording without saving
  stop_recording
  echo "Tests passed. No artifacts saved."
fi

# Final result
if [ "$TEST_SUCCESS" = true ]; then
  echo "✅ Test succeeded"
  exit 0
else
  echo "❌ All $MAX_RETRIES test attempts failed"
  echo "Check reports in $REPORT_DIR directory"
  exit 1
fi
