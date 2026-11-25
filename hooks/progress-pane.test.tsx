import { expect, test } from 'claude-code/testing'
import type { AgentInfo, On, ProcessRunResult, RenderSurface, SessionUsage } from 'claude-code'
import type { Engine, Mounted } from 'claude-code/testing'

import { parsePlan, plansFolder, stageOf } from './progress-pane-parse'

const ROOT = '/p'
const NOW = 1_800_000_000_000
const SURFACES = ['terminal', 'desktop', 'vscode', 'mobile'] as const
const PANE = {
  plugin: 'sv',
  component: 'Pane',
  requestId: 'sv-progress',
  props: {
    title: 'Progress',
    isFocused: false,
    bodyColumns: 60,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 40 },
    view: {},
  },
} as const

type Pane = Mounted<RenderSurface, 'Pane'>

const CONTRACT = '## Factory\n\n- **plans** — `docs/plans/YYYY-MM-DD-<slug>.md` (private, git-excluded)\n'

const BUILDING = `# Plan: Progress pane
**Date**: 2026-11-25
**Status**: Approved

## Phase 1 — Where we are
- [x] One
- [x] Two

## Phase 2 — What was kept
- [ ] Three
- [ ] Four

## Verification
- [ ] Validate passes.
- [ ] Owner-only: check it in the app.
`

const DRAFT = `---
status: draft
---
# Dark mode
`

function agent(fields: Partial<AgentInfo>): AgentInfo {
  return {
    id: 'a1',
    description: 'Review the change',
    type: 'general-purpose',
    status: 'running',
    kind: 'local_agent',
    taskStatus: 'running',
    label: '',
    startTime: NOW - 5 * 60000,
    cwd: ROOT,
    tokenCount: 0,
    tokenSamples: [],
    hasRow: false,
    ...fields,
  }
}

type Project = {
  files?: Record<string, string>
  agents?: AgentInfo[]
  percent?: number
  usage?: Partial<SessionUsage>
  git?: (argv: readonly string[]) => ProcessRunResult
}

function ran(exitCode: number, stdout = ''): ProcessRunResult {
  return { exitCode, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false }
}

function project(
  on: On,
  { files = {}, agents = [], percent = 42, usage = {}, git = () => ran(128) }: Project,
): { opened: string[]; runs: (readonly string[])[] } {
  const all: Record<string, string> = { '.solidvibes/manifest.json': '{}', ...files }
  const paths = Object.keys(all).map(path => `${ROOT}/${path}`)
  const opened: string[] = []
  const runs: (readonly string[])[] = []
  on('process.run', (_, e) => {
    runs.push(e.argv)
    return { value: git(e.argv) }
  })
  on('session.root', () => ({ value: ROOT }))
  on('session.cwd', () => ({ value: ROOT }))
  on('clock.now', () => ({ value: NOW }))
  on('agent.list', () => ({ value: agents }))
  on('command.register', (_, e) => ({ value: { command: e.name } }))
  on('ui.open', (_, e) => {
    opened.push(e.id)
    return { value: { isPlaced: true } }
  })
  on('session.usage', () => ({
    value: {
      startedAt: NOW - 65 * 60000,
      context: { percent, tokens: percent * 2000, window: 200000 },
      rateLimits: [],
      ...usage,
    },
  }))
  on('fs.exists', (_, e) => ({ value: paths.some(path => path === e.path || path.startsWith(`${e.path}/`)) }))
  on('fs.read', (_, e) => {
    const text = all[e.path.slice(ROOT.length + 1)]
    if (text === undefined) throw new Error('missing')
    return { value: text }
  })
  on('fs.list', (_, e) => {
    const dir = e.path.endsWith('/') ? e.path : `${e.path}/`
    const names = paths.filter(path => path.startsWith(dir)).map(path => path.slice(dir.length))
    if (names.length === 0) throw new Error('missing')
    return {
      value: names
        .filter(name => !name.includes('/'))
        .map(name => ({ name, kind: 'file' as const, size: 1, mtimeMs: 0, isLink: false })),
    }
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('turn.start', (_, e) => ({ turnId: e.turnId }))
  on('turn.complete', (_, e) => ({ text: e.answer }))
  on('tool.call', () => ({ result: {} }))
  return { opened, runs }
}

async function start($: Engine): Promise<void> {
  await $.session.start({ cwd: ROOT, surface: 'desktop', isInteractive: true })
}

async function words(ui: Pane): Promise<string> {
  const found = [...(await ui.findAll({ type: 'Text' })), ...(await ui.findAll({ type: 'Button' }))]
  return found.map(one => one.text).join('\n')
}

async function everySurface($: Engine, check: (ui: Pane, text: string) => Promise<void>): Promise<void> {
  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    await check(ui, await words(ui))
    await ui.unmount()
  }
}

test('the plans folder comes from the Factory contract', async () => {
  expect(plansFolder(CONTRACT)).toBe('docs/plans/')
  expect(plansFolder('- **plans** — `plans/`')).toBe('plans/')
  expect(plansFolder('- **plans** — none')).toBeUndefined()
  expect(plansFolder(undefined)).toBeUndefined()
})

test('a plan status is read from the body first, then the frontmatter', async () => {
  const stale = '---\nstatus: not-started\n---\n# A\n**Status**: Implemented 2026-11-20\n'
  expect(parsePlan('a.md', stale)?.status).toBe('Implemented')
  expect(parsePlan('b.md', '---\nstatus: not-started\n---\n# B\n')?.status).toBe('Approved')
  expect(parsePlan('c.md', '---\nstatus: idea\n---\n# C\n')).toBeUndefined()
  const plan = parsePlan('d.md', BUILDING)
  expect(plan?.title).toBe('Progress pane')
  expect([plan?.done, plan?.total, plan?.phases.length]).toEqual([2, 4, 2])
  expect(plan && stageOf(plan)).toBe('Build')
})

test('steps and headings inside a code block are not counted', async () => {
  const fenced = `${BUILDING}\n## Notes\n\`\`\`\n## Phase 3 — Example\n- [ ] Not a step\n\`\`\`\n`
  const plan = parsePlan('e.md', fenced)
  expect([plan?.done, plan?.total, plan?.phases.length]).toEqual([2, 4, 2])
  expect(parsePlan('f.md', '# F\n**Date**: YYYY-MM-DD\n**Status**: Draft\n')?.date).toBeUndefined()
})

test('outside a Solid Vibes project nothing opens and calls pass through', async ($, on) => {
  const opened: string[] = []
  on('session.root', () => ({ value: ROOT }))
  on('fs.exists', () => ({ value: false }))
  on('ui.open', (_, e) => {
    opened.push(e.id)
    return { value: { isPlaced: true } }
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('tool.call', () => ({ result: { kept: true } }))
  on('turn.complete', () => ({ text: 'as answered' }))

  await start($)
  const ran = await $.tool.call({ tool: 'Write', file_path: `${ROOT}/a.txt`, content: 'x' })
  const done = await $.turn.complete({ answer: 'hi', durationMs: 1, isAborted: false, turnId: 't', reason: 'answer' })

  expect(opened).toEqual([])
  expect(ran.result).toEqual({ kept: true })
  expect(done.text).toBe('as answered')
})

test('one plan mid-build is here on Build, with the steps left before your turn', async ($, on) => {
  const { opened } = project(on, {
    files: { 'AGENTS.md': CONTRACT, 'docs/plans/2026-11-25-progress-pane.md': BUILDING },
  })
  await start($)
  await $.turn.start({ text: 'go', turnId: 't1' })

  expect(opened).toEqual(['sv-progress'])
  await everySurface($, async (_, text) => {
    expect(text).toContain('Running on its own')
    expect(text).toContain('▸ Build\nAI · here')
    expect(text).toContain('Your next turn: check it works · after 2 more steps')
    expect(text).toContain('▸ Phase 2 — What was kept\n0 of 2 steps')
  })
})

test('a phase with no steps shows no step count', async ($, on) => {
  const plan = BUILDING.replace('## Phase 2', '## Phase 0 — Setup\nNothing to tick.\n\n## Phase 2')
  project(on, { files: { 'AGENTS.md': CONTRACT, 'docs/plans/2026-11-25-progress-pane.md': plan } })
  await start($)

  await everySurface($, async (_, text) => {
    expect(text).toContain('Phase 0 — Setup')
    expect(text).not.toContain('0 of 0')
  })
})

test('the state is coloured and pictures are drawn only where Svg is', async ($, on) => {
  project(on, {})
  await start($)
  await $.turn.start({ text: 'go', turnId: 't1' })

  await everySurface($, async ui => {
    expect((await ui.find({ type: 'Text', text: '● Running on its own' }))?.props.color).toBe('success')
    const pictures = await ui.findAll({ type: 'Svg' })
    expect(pictures.length > 0).toBe(ui.surface !== 'terminal')
  })
})

test('several plans list the one that needs you first', async ($, on) => {
  project(on, {
    files: {
      'AGENTS.md': CONTRACT,
      'docs/plans/2026-11-01-a-build.md': BUILDING,
      'docs/plans/2026-11-02-dark-mode.md': DRAFT,
    },
  })
  await start($)

  await everySurface($, async (_, text) => {
    expect(text).toContain('2 open\n1 needs you')
    expect(text).toContain('Open work')
    expect(text.indexOf('Dark mode')).toBeLessThan(text.indexOf('Progress pane'))
  })
})

test('with no plan it works without one and lists files changed this chat', async ($, on) => {
  project(on, {})
  await start($)
  await $.tool.call({ tool: 'Write', file_path: `${ROOT}/src/app.ts`, content: 'x' })

  await everySurface($, async (_, text) => {
    expect(text).toContain('Working without a plan')
    expect(text).toContain('src/app.ts')
    expect(text).toContain('Your turn')
  })
})

test('a helper ending its turn does not end the main turn', async ($, on) => {
  project(on, {})
  await start($)
  await $.turn.start({ text: 'go', turnId: 't1' })
  await $.turn.complete({ answer: 'done', durationMs: 1, isAborted: false, turnId: 't2', reason: 'answer', agentId: 'a1' })

  await everySurface($, async (_, text) => {
    expect(text).toContain('Running on its own')
  })
})

test('a helper still running after the main turn shows Still working', async ($, on) => {
  project(on, { agents: [agent({}), agent({ id: 'a2', status: 'completed' })] })
  await start($)
  await $.turn.start({ text: 'go', turnId: 't1' })
  await $.turn.complete({
    answer: 'Built it.\n\nShould I open the pull request?',
    durationMs: 1,
    isAborted: false,
    turnId: 't1',
    reason: 'answer',
  })

  await everySurface($, async (_, text) => {
    expect(text).toContain('Still working: 1 helper running')
    expect(text).toContain('Review the change\nrunning 5 min')
  })
})

test('a helper ending its run turns Still working into Your turn', async ($, on) => {
  project(on, { agents: [agent({}), agent({ id: 'a3', status: 'idle' })] })
  await start($)
  await $.turn.complete({ answer: 'Started a review.', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })
  await $.turn.complete({ answer: 'Reviewed.', durationMs: 1, isAborted: false, turnId: 't2', reason: 'answer', agentId: 'a1' })

  await everySurface($, async (_, text) => {
    expect(text).toContain('Your turn')
    expect(text).not.toContain('Still working')
  })
})

test('writing code refreshes no git, writing a Markdown file does', async ($, on) => {
  const { runs } = project(on, {})
  await start($)
  const before = runs.length
  await $.tool.call({ tool: 'Write', file_path: `${ROOT}/src/app.ts`, content: 'x' })
  expect(runs.length).toBe(before)
  await $.tool.call({ tool: 'Write', file_path: `${ROOT}/docs/intent.md`, content: 'x' })
  expect(runs.length).toBeGreaterThan(before)
})

test('with no helper running the main turn ending is your turn, with the last ask', async ($, on) => {
  project(on, {})
  await start($)
  await $.turn.complete({
    answer: 'Built it.\n\nShould I open the pull request?',
    durationMs: 1,
    isAborted: false,
    turnId: 't1',
    reason: 'answer',
  })

  await everySurface($, async (_, text) => {
    expect(text).toContain('Your turn')
    expect(text).toContain('Should I open the pull request?')
    expect(text).not.toContain('Built it.')
  })
})

test('a file opens in the reader and Back returns', async ($, on) => {
  project(on, { files: { 'docs/intent.md': '# Why\n\nFor everyone.' }, percent: 85 })
  await start($)

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    await ui.press({ key: 'fold:files' })
    await ui.press({ key: 'file:docs/intent.md' })
    expect((await ui.find({ type: 'Markdown' }))?.props.text).toBe('# Why\n\nFor everyone.')
    await ui.press({ key: 'back' })
    expect(await ui.find({ type: 'Markdown' })).toBeUndefined()
    await ui.press({ key: 'fold:files' })
    await ui.press({ key: 'fold:session' })
    const text = await words(ui)
    expect(text).toContain('Session\n⌄\n85% context')
    expect(text).toContain('Type /clear. The handover keeps your place.')
    await ui.press({ key: 'fold:session' })
    await ui.unmount()
  }
})

test('a value an earlier version stored is declined', async ($, on) => {
  on('state.get', () => ({ value: { value: { isGated: true, plans: 'old' }, version: 1 } }))

  await everySurface($, async (_, text) => {
    expect(text).toContain('This is not a Solid Vibes project.')
  })
})

const LOG = `a1b2c3d\tPick the database

docs/decisions/2026-11-25-database.md
AGENTS.md
e4f5a6b\tExplain sign-in

docs/how-it-works/sign-in.md
docs/decisions/2026-11-25-database.md
`

test('what was saved to the project comes from git, newest first', async ($, on) => {
  const { runs } = project(on, {
    files: { 'AGENTS.md': CONTRACT, 'docs/plans/2026-11-25-progress-pane.md': BUILDING },
    git: argv => ran(0, argv[2] === 'log' ? LOG : '?? docs/design/brand.md\n M src/app.ts\n'),
  })
  await start($)

  expect(runs[0]).toContain('--since=2026-11-25 00:00')
  expect(runs[0]).toContain('--no-optional-locks')
  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    await ui.press({ key: 'fold:saved' })
    expect(await words(ui)).toContain(
      [
        'brand.md\nDesign · Not saved in git yet',
        '2026-11-25-database.md\nDecision · Pick the database',
        'AGENTS.md\nRule · Pick the database',
        'sign-in.md\nHow it works · Explain sign-in',
      ].join('\n'),
    )
    await ui.press({ key: 'fold:saved' })
    await ui.unmount()
  }
})

test('without git the saved section is hidden', async ($, on) => {
  project(on, { git: () => ran(128) })
  await start($)

  await everySurface($, async (_, text) => {
    expect(text).not.toContain('Saved to the project')
  })
})

test('session details show what the reading has, and leave out what it lacks', async ($, on) => {
  project(on, {
    usage: {
      context: {
        percent: 30,
        tokens: 60000,
        window: 200000,
        breakdown: {
          categories: [
            { name: 'System prompt', tokens: 3000, color: 'x', isDeferred: false, kind: 'used' },
            { name: 'Messages', tokens: 50000, color: 'x', isDeferred: false, kind: 'used' },
            { name: 'Free space', tokens: 140000, color: 'x', isDeferred: false, kind: 'free' },
          ],
          mcpTools: [
            { name: 'mcp__docs__read', serverName: 'docs', tokens: 1500, isLoaded: true },
            { name: 'mcp__docs__write', serverName: 'docs', tokens: 1500, isLoaded: true },
          ],
        } as unknown as NonNullable<SessionUsage['context']['breakdown']>,
      },
      rateLimits: [{ kind: 'five_hour', percentUsed: 23 }],
      cost: { usd: 1.234 },
    },
  })
  await start($)

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    await ui.press({ key: 'fold:session' })
    const text = await words(ui)
    for (const line of [
      'Session\n⌄\n30% context',
      '■ Messages',
      '50k tokens · 25%',
      '■ Free space',
      '140k tokens · 70%',
      'Usage limit\n23% of five hours',
      'Cost so far\nabout $1.23 (an estimate)',
      'Started\n1 h 5 min ago',
      'docs\n3k tokens',
    ]) {
      expect(text).toContain(line)
    }
    await ui.press({ key: 'fold:session' })
    await ui.unmount()
  }
})

test('session details without a breakdown, limit or cost show the rest', async ($, on) => {
  project(on, {})
  await start($)

  for (const surface of SURFACES) {
    const ui = await $.ui.mount({ ...PANE, surface })
    await ui.press({ key: 'fold:session' })
    const text = await words(ui)
    expect(text).toContain('42% of the context used')
    expect(text).toContain('Started\n1 h 5 min ago')
    expect(text).not.toContain('Usage limit')
    expect(text).not.toContain('Cost so far')
    expect(text).not.toContain('Connectors')
    await ui.press({ key: 'fold:session' })
    await ui.unmount()
  }
})
