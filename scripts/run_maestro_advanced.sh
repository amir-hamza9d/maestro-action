#!/bin/bash

set -euo pipefail
set -x  # Print all commands for visibility

# Default configuration
TMP_FILE=_fail_process_local
APP_ID=pdfreader.pdfviewer.officetool.pdfscanner
MAESTRO_BIN="$HOME/.maestro/bin/maestro"
MAX_RETRIES=3
TEST_SUCCESS=false
MAESTRO_TEST_DIR="flows"  # Default directory containing your test flows
TEST_FLOW=""  # Specific test flow to run (empty means run all)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --app-id)
      APP_ID="$2"
      shift 2
      ;;
    --test-dir)
      MAESTRO_TEST_DIR="$2"
      shift 2
      ;;
    --flow)
      TEST_FLOW="$2"
      shift 2
      ;;
    --retries)
      MAX_RETRIES="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--app-id APP_ID] [--test-dir DIR] [--flow FLOW_FILE] [--retries NUM]"
      exit 1
      ;;
  esac
done

# Create output directory for reports and artifacts if it doesn't exist
REPORT_DIR="artifacts"
mkdir -p "$REPORT_DIR"

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
if [[ -n "$TEST_FLOW" ]]; then
  echo "Running specific flow: $TEST_FLOW"
  TEST_PATH="$MAESTRO_TEST_DIR/$TEST_FLOW"
else
  echo "Running all flows in directory"
  TEST_PATH="$MAESTRO_TEST_DIR/"
fi

# Run Maestro tests with retries
for i in $(seq 1 $MAX_RETRIES); do
  echo "===== Run E2E Attempt: $i ====="
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

  if $MAESTRO_BIN test "$TEST_PATH" --env=APP_ID="$APP_ID" --format=html --output "$REPORT_DIR/report_${TIMESTAMP}_$i.html"; then
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
      # Increasing delay before retry
      sleep $((i * 10))
    fi
  fi
done

# If tests were successful, stop recording without saving artifacts
if [ "$TEST_SUCCESS" = true ]; then
  # Just stop the recording without saving
  stop_recording
  echo "Tests passed. No artifacts saved."
fi

# Generate a summary report in HTML format
SUMMARY_HTML="$REPORT_DIR/summary_$TIMESTAMP.html"
cat > "$SUMMARY_HTML" << EOF
<!DOCTYPE html>
<html>
<head>
  <title>Maestro Test Summary</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; }
    .success { color: green; font-weight: bold; }
    .failure { color: red; font-weight: bold; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
  </style>
</head>
<body>
  <h1>Maestro Test Summary</h1>
  <table>
    <tr><th>Date</th><td>$(date)</td></tr>
    <tr><th>App ID</th><td>$APP_ID</td></tr>
    <tr><th>Test Path</th><td>$TEST_PATH</td></tr>
    <tr><th>Result</th><td class="$([ "$TEST_SUCCESS" = true ] && echo 'success' || echo 'failure')">$([ "$TEST_SUCCESS" = true ] && echo 'SUCCESS' || echo 'FAILURE')</td></tr>
    <tr><th>Attempts</th><td>$([[ "$TEST_SUCCESS" = true ]] && echo "$i/$MAX_RETRIES" || echo "$MAX_RETRIES/$MAX_RETRIES")</td></tr>
  </table>
</body>
</html>
EOF

echo "Summary report generated at $SUMMARY_HTML"

# Final result
if [ "$TEST_SUCCESS" = true ]; then
  echo "✅ Test succeeded"
  exit 0
else
  echo "❌ All $MAX_RETRIES test attempts failed"
  echo "Check reports in $REPORT_DIR directory"
  exit 1
fi
