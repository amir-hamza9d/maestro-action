# PDF Reader App Automation Tests

Automated testing suite for the PDF Reader mobile application using Maestro, a mobile UI testing framework.

## Overview

This project contains automated tests for the PDF Reader Android application (package: `pdfreader.pdfviewer.officetool.pdfscanner`). The tests verify core functionality such as:

- Basic app navigation and UI elements
- PDF file opening and viewing
- Permission handling
- Demo PDF verification

## Project Structure

- `flows/` - Contains Maestro test flows in YAML format
  - `baseCheck.yaml` - Basic app functionality verification
  - `permission.yaml` - Tests permission handling
  - `verify_demo_pdf.yaml` - Verifies demo PDF functionality
  - `smoke.yaml` - Combines multiple tests for smoke testing
- `hooks/` - Contains reusable test components
  - `beforeHook.yaml` - Setup operations run before tests
- `scripts/` - Contains shell scripts for test execution
  - `run_maestro_simple.sh` - Basic test runner
  - `run_maestro_advanced.sh` - Advanced test runner with retries
  - `run_maestro_tests.sh` - Main test execution script
  - `run_failed_tests.sh` - Script to re-run failed tests
- `artifacts/` - Directory for test reports and failure artifacts
- `app-elements/` - Contains JavaScript helper files for test flows

## Prerequisites

- Maestro CLI installed (`~/.maestro/bin/maestro`)
- Android SDK installed with environment variables set
- Connected Android device or emulator

## Running Tests

### Basic Test Run

```bash
./scripts/run_maestro_simple.sh
```

This will run all tests in the `flows/` directory and generate an HTML report in the `artifacts/` directory.

### Advanced Test Run with Retries

```bash
./scripts/run_maestro_advanced.sh [--app-id APP_ID] [--test-dir DIR] [--flow FLOW_FILE] [--retries NUM]
```

Options:
- `--app-id` - Specify the application ID (default: pdfreader.pdfviewer.officetool.pdfscanner)
- `--test-dir` - Specify the test directory (default: flows)
- `--flow` - Run a specific flow file
- `--retries` - Number of retry attempts (default: 3)

### Re-running Failed Tests

```bash
./scripts/run_failed_tests.sh
```

This will re-run only the tests that failed in the previous run, as listed in `failed_tests.txt`.

## Test Reports

Test reports are generated in HTML format in the `artifacts/` directory. For failed tests, the following artifacts are collected:
- Screenshots
- Screen recordings
- Detailed error logs

## Test Configuration

The `.maestro/config.yaml` file contains global configuration for test execution, including:
- Flow inclusion/exclusion patterns
- Tag-based filtering
- Execution order settings

## Writing Tests

Tests are written in YAML format following the Maestro syntax. Example:

```yaml
appId: pdfreader.pdfviewer.officetool.pdfscanner
---
- assertVisible: 
    text: "Open"
    label: "Verify the Open button is visible"
- tapOn: 
    text: "Open"
    label: "Tap on open for file manager"
```

## Dependencies

This project uses the following dependencies:
- [Maestro](https://maestro.mobile.dev/) - Mobile UI testing framework
- [js-yaml](https://github.com/nodeca/js-yaml) - YAML parser/serializer for JavaScript helpers
- Android Emulator
- Java

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.


Automate with Love ❤️
