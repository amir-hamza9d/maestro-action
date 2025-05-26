# Applitools Integration for Visual Testing

This document explains how to use the Applitools integration for visual testing alongside the existing pixelmatch-based visual regression testing system.

## Overview

The integration allows you to:
1. Use your existing screenshot directory structure
2. Compare screenshots using Applitools' AI-powered visual testing
3. Get detailed visual comparison reports through the Applitools dashboard
4. Run both the existing pixelmatch comparison and Applitools comparison independently

## Prerequisites

1. An Applitools account (sign up at [https://applitools.com/](https://applitools.com/))
2. Applitools API key (available in your Applitools dashboard)

## Setup

1. Install the required dependencies:
   ```bash
   npm install @applitools/eyes-images dotenv --save
   ```

2. Set your Applitools API key using one of these methods:

   **Option 1: Using a .env file (recommended)**

   The project already includes a `.env` file with a placeholder for your API key:
   ```
   # File: .env
   APPLITOOLS_API_KEY=your_api_key_here
   ```

   Simply edit this file and replace `your_api_key_here` with your actual Applitools API key.

   If the `.env` file doesn't exist, you can create it by copying the example file:
   ```bash
   cp .env.example .env
   ```

   **Option 2: Set as an environment variable**
   ```bash
   export APPLITOOLS_API_KEY=your_api_key_here
   ```

   **Option 3: Pass directly when running the script**
   ```bash
   APPLITOOLS_API_KEY=your_api_key_here npm run applitools-compare
   ```

## Usage

### Running Applitools Visual Tests

Run the Applitools comparison script:

```bash
npm run applitools-compare
```

Or with environment variables:

```bash
APPLITOOLS_API_KEY=your_api_key_here APPLITOOLS_APP_NAME="Your App Name" npm run applitools-compare
```

### Configuration Options

You can configure the Applitools integration using environment variables:

| Environment Variable | Description | Default Value |
|---------------------|-------------|---------------|
| `APPLITOOLS_API_KEY` | Your Applitools API key (required) | None |
| `APPLITOOLS_APP_NAME` | Name of your application | "Maestro App" |
| `APPLITOOLS_BATCH_NAME` | Name of the test batch | "Visual Tests - [current date]" |
| `APPLITOOLS_MATCH_LEVEL` | Match level for comparison (Exact, Strict, Content, Layout) | "Strict" |
| `DEBUG` | Enable debug logging | false |

Example:

```bash
APPLITOOLS_API_KEY=your_api_key_here APPLITOOLS_APP_NAME="My Mobile App" APPLITOOLS_MATCH_LEVEL="Layout" npm run applitools-compare
```

## How It Works

The Applitools integration script:

1. Reads screenshots from the `Screen-shots/Actual` directory
2. Checks if corresponding screenshots exist in the `Screen-shots/Expected` directory (for logging purposes)
3. Sends the actual screenshots to Applitools for comparison
4. Applitools compares them against its own cloud-stored baselines
5. On the first run, Applitools will create new baselines from the actual images
6. On subsequent runs, Applitools will compare against the stored baselines
7. Results are displayed in the console and available in detail on the Applitools dashboard

**Note about baselines**: Applitools manages its own baselines in the cloud, separate from your local `Screen-shots/Expected` directory. The script checks for the existence of files in the `Expected` directory only for logging purposes. The actual comparison is done against Applitools' cloud-stored baselines.

## Using Both Testing Systems

You can run both the existing pixelmatch comparison and the Applitools comparison:

```bash
# Run the existing pixelmatch comparison
npm run compare-screenshots

# Run the Applitools comparison
npm run applitools-compare
```

## Viewing Results

After running the Applitools comparison, you can view detailed results in the Applitools dashboard:
[https://eyes.applitools.com/app/test-results/](https://eyes.applitools.com/app/test-results/)

The dashboard provides:
- Visual diffs highlighting the differences
- Ability to accept or reject changes
- Detailed test history
- Advanced analytics and reporting

### Managing Baselines in Applitools

Applitools maintains its own baseline images in the cloud. To manage these baselines:

1. Log in to your Applitools dashboard at [https://eyes.applitools.com/](https://eyes.applitools.com/)
2. Navigate to the test results page
3. For each test, you can:
   - **Accept** changes to update the baseline
   - **Reject** changes to keep the current baseline
   - **Delete** baselines you no longer need

When you accept changes, the new image becomes the baseline for future comparisons. This is separate from your local `Screen-shots/Expected` directory.

## Continuous Integration

To use this integration in CI/CD pipelines, set the `APPLITOOLS_API_KEY` environment variable in your CI environment.

Example for GitHub Actions:

```yaml
jobs:
  visual-testing:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Install dependencies
        run: npm install
      - name: Run Applitools visual tests
        run: npm run applitools-compare
        env:
          APPLITOOLS_API_KEY: ${{ secrets.APPLITOOLS_API_KEY }}
          APPLITOOLS_APP_NAME: "My Mobile App"
```

## Finding Your Applitools API Key

To find your Applitools API key:

1. Log in to your Applitools account at [https://eyes.applitools.com/](https://eyes.applitools.com/)
2. Click on your profile icon in the top-right corner
3. Select "My API Key"
4. Copy the API key displayed

## Troubleshooting

### API Key Issues

If you see an error about the API key:

```
❌ APPLITOOLS_API_KEY environment variable is not set. Please set it before running this script.
```

Make sure to set the environment variable using one of the methods described in the Setup section.

If you see an error like:

```
❌ Unhandled error: IllegalArgument: apiKey must be an alphanumeric string.
```

Make sure you're using a valid Applitools API key. The key should be a long alphanumeric string provided by Applitools.

### Missing Directories

If you see errors about missing directories, ensure your screenshot directories exist:

```
Screen-shots/
├── Expected/
├── Actual/
└── Diff/
```

### Connection Issues

If you experience connection issues with Applitools, check:
1. Your internet connection
2. Firewall settings that might block outgoing connections
3. API key validity

## Additional Resources

- [Applitools Documentation](https://applitools.com/docs/)
- [Eyes-Images SDK Documentation](https://applitools.com/docs/api/eyes-sdk/index-gen/classindex-images-javascript.html)
