/*
 * Browser smoke test for the exported Web build.
 *
 *   python3 -m http.server 4176 --directory web/play &
 *   node Tools/smoke.mjs http://127.0.0.1:4176/
 *
 * Boots the build in a portrait phone, starts a campaign battle through the
 * game's own debug hook, builds a real tower, calls a wave and fast-forwards
 * the simulation, then checks a landscape window still letterboxes a portrait
 * board. Screenshots land in /tmp/wg-shots.
 */
import { createRequire } from 'node:module'
import { mkdirSync } from 'node:fs'

const require = createRequire(import.meta.url)
const { chromium } = require('../../starfall-squadron/node_modules/playwright')

const url = process.argv[2] || 'http://127.0.0.1:4176/'
const failures = []
const errors = []

mkdirSync('/tmp/wg-shots', { recursive: true })

async function stateOf(page) {
  try {
    const raw = await page.evaluate(() => window.__wonderguardState || null)
    if (!raw) return null
    return typeof raw === 'string' ? JSON.parse(raw) : raw
  } catch (error) {
    return null
  }
}

/** The game publishes state every few frames; poll rather than sleep. */
async function waitForState(page, predicate, timeout = 20000) {
  const start = Date.now()
  let last = null
  while (Date.now() - start < timeout) {
    last = await stateOf(page)
    if (last && predicate(last)) return last
    await page.waitForTimeout(250)
  }
  return last
}

async function command(page, value) {
  await page.evaluate((text) => {
    window.__wonderguardCommand = text
  }, value)
}

const browser = await chromium.launch()

const context = await browser.newContext({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
  hasTouch: true,
  isMobile: true,
})
const page = await context.newPage()
page.on('pageerror', (error) => errors.push(`phone: ${error.message}`))
page.on('console', (message) => {
  if (message.type() === 'error') errors.push(`console: ${message.text()}`)
})

await page.goto(url, { waitUntil: 'domcontentloaded' })
await page.waitForSelector('#canvas', { timeout: 60000 })
await page.waitForTimeout(6000)

const layout = await page.evaluate(() => {
  const canvas = document.querySelector('#canvas')
  const rect = canvas ? canvas.getBoundingClientRect() : null
  const gate = document.querySelector('#lja-rotate')
  return {
    canvas: rect
      ? {
          w: Math.round(rect.width),
          h: Math.round(rect.height),
          top: Math.round(rect.top),
          left: Math.round(rect.left),
        }
      : null,
    window: { w: innerWidth, h: innerHeight },
    bridge: window.Wonderguard ? window.Wonderguard.version : null,
    client: typeof window.LittleJoyArcade === 'object',
    gate: gate ? getComputedStyle(gate).display !== 'none' : false,
  }
})
console.log('layout', JSON.stringify(layout))
if (!layout.canvas) failures.push('phone: no canvas')
if (!layout.bridge) failures.push('phone: arcade bridge missing')
if (!layout.client) failures.push('phone: arcade client missing')
if (layout.canvas && layout.canvas.h < layout.window.h * 0.9) {
  failures.push(`phone: canvas is ${layout.canvas.h}px tall in a ${layout.window.h}px window`)
}
if (layout.canvas && layout.canvas.w > layout.window.w + 1) {
  failures.push(`phone: canvas is ${layout.canvas.w}px wide in a ${layout.window.w}px window`)
}
if (layout.canvas && layout.canvas.w < layout.window.w * 0.99) {
  failures.push(`phone: canvas is ${layout.canvas.w}px wide in a ${layout.window.w}px window`)
}
if (layout.canvas && layout.canvas.h < layout.window.h * 0.99) {
  failures.push(`phone: canvas is ${layout.canvas.h}px tall in a ${layout.window.h}px window`)
}
if (layout.gate) failures.push('phone: the portrait gate must be hidden in portrait')

let state = await waitForState(page, (s) => s.screen === 'title', 20000)
console.log('title state', JSON.stringify(state))
if (!state || state.screen !== 'title') {
  failures.push(`phone: title screen did not boot (${JSON.stringify(state)})`)
}
await page.screenshot({ path: '/tmp/wg-shots/title.png' })

await command(page, 'start:campaign:1')
state = await waitForState(page, (s) => s.screen === 'battle', 25000)
console.log('battle state', JSON.stringify(state))
if (!state || state.screen !== 'battle') failures.push('phone: could not start a battle')
if (state && state.lives !== 20) failures.push(`phone: level one should start with 20 lives (${state.lives})`)
await page.screenshot({ path: '/tmp/wg-shots/battle.png' })

await command(page, 'build:ballista')
state = await waitForState(page, (s) => s.towers >= 1, 10000)
console.log('build state', JSON.stringify(state))
if (!state || state.towers < 1) failures.push(`phone: tower did not build (${JSON.stringify(state)})`)
if (state && state.gold >= 220) failures.push('phone: building did not spend gold')

await command(page, 'wave')
state = await waitForState(page, (s) => s.phase === 'wave', 10000)
if (!state || state.phase !== 'wave') failures.push(`phone: wave did not start (${JSON.stringify(state)})`)

await command(page, 'advance:20')
state = await waitForState(page, (s) => s.enemies >= 1 || s.cleared >= 1, 15000)
console.log('after wave', JSON.stringify(state))
if (!state || (state.enemies < 1 && state.cleared < 1)) {
  failures.push(`phone: the wave produced nothing (${JSON.stringify(state)})`)
}
await page.screenshot({ path: '/tmp/wg-shots/wave.png' })

const wide = await browser.newContext({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 })
const widePage = await wide.newPage()
widePage.on('pageerror', (error) => errors.push(`desktop: ${error.message}`))
await widePage.goto(url, { waitUntil: 'domcontentloaded' })
await widePage.waitForSelector('#canvas', { timeout: 60000 })
await widePage.waitForTimeout(6000)
const wideLayout = await widePage.evaluate(() => {
  const canvas = document.querySelector('#canvas')
  const rect = canvas.getBoundingClientRect()
  const gate = document.querySelector('#lja-rotate')
  return {
    w: Math.round(rect.width),
    h: Math.round(rect.height),
    gate: gate ? getComputedStyle(gate).display !== 'none' : false,
    window: { w: innerWidth, h: innerHeight },
  }
})
console.log('desktop layout', JSON.stringify(wideLayout))
if (!wideLayout.gate) failures.push('desktop: a landscape window must show the portrait gate')
if (wideLayout.w < wideLayout.window.w * 0.99 || wideLayout.h < wideLayout.window.h * 0.99) {
  failures.push(`desktop: canvas ${wideLayout.w}x${wideLayout.h} must fill the window`)
}
await widePage.screenshot({ path: '/tmp/wg-shots/desktop.png' })

await browser.close()
console.log('errors', JSON.stringify(errors.slice(0, 12)))
if (errors.length) failures.push(`${errors.length} console/page error(s)`)

if (failures.length) {
  console.error('SMOKE FAILED')
  for (const failure of failures) console.error(' - ' + failure)
  process.exit(1)
}
console.log('SMOKE OK')
