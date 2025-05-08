#!/bin/bash

set -euo pipefail

# Configuration
APP_ID=pdfreader.pdfviewer.officetool.pdfscanner
MAESTRO_BIN="$HOME/.maestro/bin/maestro"
FLOWS_DIR="flows"
FAILED_FLOWS_FILE="failed_tests.txt"
REPORT_DIR="artifacts"

echo "=== 🚀 Starting Maestro test execution... ==="
echo "📁 Test directory: $FLOWS_DIR"
echo "📱 App ID: $APP_ID"

# Create reports directory if it doesn't exist
mkdir -p "$REPORT_DIR"
echo "📊 Reports will be saved to: $REPORT_DIR"

# Clear the failed flows file
> "$FAILED_FLOWS_FILE"
echo "🧹 Cleared previous failed tests file"

# Run all flows and generate HTML report
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
echo "⏱️  Test started at: $(date)"
echo "🧪 Running all tests in $FLOWS_DIR directory..."

if ! $MAESTRO_BIN test "$FLOWS_DIR/" --env=APP_ID="$APP_ID" --format=html --output "$REPORT_DIR/report_${TIMESTAMP}.html"; then
  echo "❌ Some tests failed. Extracting failed flow paths..."
  
  # Extract failed flow paths from the report
  # Look for buttons with ERROR or FAILURE status
  grep -o '<button class="btn btn-danger"[^>]*>[^<]*</button>' "$REPORT_DIR/report_${TIMESTAMP}.html" | 
    grep -o '>[^:]*:' | 
    sed 's/>//g' | 
    sed 's/://g' | 
    while read -r flow; do
      if [ -n "$flow" ]; then
        # Only add if it's not already in the file and trim whitespace
        flow=$(echo "$flow" | xargs)
        if ! grep -q "$flow" "$FAILED_FLOWS_FILE"; then
          echo "$FLOWS_DIR/${flow}.yaml" >> "$FAILED_FLOWS_FILE"
          echo "   ↳ Failed: $FLOWS_DIR/${flow}.yaml"
        fi
      fi
    done
  
  echo "📝 Failed flows saved in $FAILED_FLOWS_FILE"
  echo "📊 Full report available at: $REPORT_DIR/report_${TIMESTAMP}.html"
  echo "🔄 Run './scripts/run_failed_tests.sh' to retry failed tests"
  
  # Display count of failed tests
  FAILED_COUNT=$(wc -l < "$FAILED_FLOWS_FILE")
  echo "📊 Summary: $FAILED_COUNT test(s) failed"
else
  echo "✅ All tests passed successfully!"
  echo "📊 Full report available at: $REPORT_DIR/report_${TIMESTAMP}.html"
fi

echo "⏱️  Test finished at: $(date)"
