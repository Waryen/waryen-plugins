# Web: headless

## The repo's suite

- Playwright: `npx playwright test <spec> --reporter=line`. It runs headless by default. With several browser projects configured, pass `--project` with the chromium one.
- Cypress: `npx cypress run --headless --spec <spec>`.
- Point the suite at the run's own dev server (Launch, below) through its base-URL setting, never at a shared or production environment.
- Playwright empties its output directory at the start of every run. Give each run its own folder (`--output <run folder>/evidence/<n>/pw-<spec>`), so earlier evidence survives.

## warstack's harness (repo memory `e2e/`)

Build it once, then reuse it:

1. In `~/.warstack/repos/<repo-key>/e2e/`: `npm init -y`, then `npm install -D @playwright/test`, then `npx playwright install chromium`.
2. `playwright.config.ts`:
   - `use: { baseURL: process.env.BASE_URL, trace: 'retain-on-failure' }`;
   - `outputDir: process.env.PW_OUTPUT`;
   - chromium only.
3. One spec per feature, named after its `features/<feature>.md`.
   - Locate by role, label or test id (`getByRole`, `getByLabel`, `getByTestId`), never by generated class names or position.
   - End each check with `await page.screenshot({ path: testInfo.outputPath('<check>.png') })`, so passing checks carry evidence too.
4. Run it from that folder, with its own output folder: `BASE_URL=http://127.0.0.1:<port> PW_OUTPUT=<run folder>/evidence/<n>/pw-<spec> npx playwright test <spec>`. For a bug's two attempts, add `--repeat-each 2` to the same command, so both attempts land in one output folder. Each attempt gets a fresh browser context; server-side state needs the spec's own reset.

Keep it shaped like a suite the repo would commit (standard layout, relative paths only), so shipping it to the repo is a copy.

## Launch

- Start the app from the worktree with its dev command on a free port, in the background, logging to `evidence/<n>/server.log`. Note its PID.
- It is ready when `curl -sf http://127.0.0.1:<port>/` (or its health route) answers. After 3 minutes without an answer, read the log and report.
- Stop it by that PID once the checks are done.

## Evidence

- A screenshot of the state that proves each check.
- For styling checks, the computed value: `await locator.evaluate(el => getComputedStyle(el).color)`.
- The trace, on failure.
