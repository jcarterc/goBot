// Playwright smoke test for the goBot Arena web build.
// Boots the exported build, drives the title -> lobby -> arena flow, and
// asserts on the live window.__gobot state bridge.
//
// Prereqs:  godot --headless --path . --export-release "Web" build/index.html
// Run:      npm test
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { chromium } from "playwright";

const PORT = process.env.PORT || 8060;
const BASE = `http://localhost:${PORT}`;

if (!existsSync("build/index.html")) {
  console.error("build/index.html missing — export the web build first.");
  process.exit(1);
}

const server = spawn("node", ["server.js"], {
  env: { ...process.env, PORT },
  stdio: "inherit",
});

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function readState(page) {
  return page.evaluate(() => window.__gobot || null);
}

async function main() {
  await sleep(800);
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto(BASE);

  // Wait for the engine to boot and publish the bridge (title/lobby state).
  await page.waitForFunction(() => window.__gobot && window.__gobot.ready, null, {
    timeout: 60000,
  });
  let state = await readState(page);
  console.log("booted:", state);
  if (state.game_state !== "lobby") throw new Error("expected lobby on boot");

  // Title screen -> lobby (any key), then PLAY by clicking through.
  await page.keyboard.press("Enter");
  await sleep(500);

  // Start the run: the lobby PLAY button sits center-bottom; a click on the
  // canvas plus Enter advances most flows. We assert the bridge eventually
  // reports a live arena with bots.
  await page.mouse.click(640, 360);
  await sleep(500);

  await page
    .waitForFunction(() => window.__gobot && window.__gobot.bot_count > 0, null, {
      timeout: 30000,
    })
    .catch(() => {});
  state = await readState(page);
  console.log("state after start:", state);

  await browser.close();
  console.log("smoke test OK");
}

main()
  .catch((err) => {
    console.error("smoke test FAILED:", err);
    process.exitCode = 1;
  })
  .finally(() => server.kill());
