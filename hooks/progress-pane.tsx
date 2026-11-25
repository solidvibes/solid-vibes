import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, RenderElement, RenderInput, RenderNode, SessionUsage } from 'claude-code'

import { KNOWLEDGE, STAGES, closingParagraph, parsePlan, plansFolder, savedRows, stageOf } from './progress-pane-parse'
import type { Details, Helper, Plan, Saved, Snapshot, Tokens, Turn } from './progress-pane-state'

type Engine = EngineInterface

const PANE = 'sv-progress'
const MANIFEST = '.solidvibes/manifest.json'
const KEPT_FILES = ['.solidvibes/handover.md', 'docs/intent.md']
const WRITE_TOOLS = new Set(['Edit', 'Write', 'MultiEdit', 'NotebookEdit'])
const RESTING = new Set(['idle', 'completed', 'failed', 'killed'])
const OPEN_BY_DEFAULT: Record<string, boolean> = { now: true, journey: true }
const READER_CAP = 20000

const EMPTY: Snapshot = { isGated: false, plans: [], helpers: [], files: [] }
const IDLE: Turn = { isRunning: false, lastAsk: '', recent: [] }

const snapshot = atom({ plugin: 'sv', key: 'snapshot' } as const, EMPTY, { shape: 'snapshot-2' })
const turn = atom({ plugin: 'sv', key: 'turn' } as const, IDLE, { shape: 'turn-1' })
const folds = atom({ plugin: 'sv', key: 'folds' } as const, {}, { shape: 'folds-1' })
const reading = atom({ plugin: 'sv', key: 'reading' } as const, null, { shape: 'reading-1' })
const opened = atom({ plugin: 'sv', key: 'opened' } as const, null, { shape: 'opened-1' })

async function rootOf($: Engine): Promise<string> {
  return (await $.session.root().catch(() => undefined)) ?? (await $.session.cwd())
}

async function isGated($: Engine, root: string): Promise<boolean> {
  return $.fs.exists(`${root}/${MANIFEST}`).catch(() => false)
}

async function readText($: Engine, path: string): Promise<string | undefined> {
  return $.fs.read(path).catch(() => undefined)
}

async function loadPlans($: Engine, root: string): Promise<Plan[]> {
  const folder = plansFolder(await readText($, `${root}/AGENTS.md`))
  const candidates = folder === undefined ? ['docs/plans/', 'plans/'] : [folder]
  for (const dir of candidates) {
    const entries = await $.fs.list(`${root}/${dir}`).catch(() => undefined)
    if (entries === undefined) continue
    const plans: Plan[] = []
    for (const entry of entries.filter(one => one.kind === 'file' && one.name.endsWith('.md'))) {
      const text = await readText($, `${root}/${dir}${entry.name}`)
      const plan = text === undefined ? undefined : parsePlan(`${dir}${entry.name}`, text)
      if (plan?.status === 'Draft' || plan?.status === 'Approved') plans.push(plan)
    }
    return plans.sort((a, b) => a.path.localeCompare(b.path))
  }
  return []
}

async function loadHelpers($: Engine, plans: Plan[], ended?: string): Promise<Helper[]> {
  const agents = await $.agent.list().catch(() => [])
  const now = await $.clock.now()
  return agents
    .filter(agent => !RESTING.has(agent.status) && agent.id !== ended)
    .map(agent => ({
      id: agent.id,
      description: agent.description,
      minutes: Math.max(0, Math.floor((now - agent.startTime) / 60000)),
      plan: plans.find(plan => agent.description.includes(baseName(plan.path).replace(/\.md$/, '')))?.path,
    }))
}

function baseName(path: string): string {
  return path.slice(path.lastIndexOf('/') + 1)
}

async function refresh($: Engine, withUsage: boolean, ended?: string): Promise<void> {
  const root = await rootOf($)
  if (!(await isGated($, root))) {
    await update($, snapshot, () => EMPTY)
    return
  }
  const plans = await loadPlans($, root)
  const helpers = await loadHelpers($, plans, ended)
  const files = plans.map(plan => plan.path)
  for (const path of KEPT_FILES) {
    if (await $.fs.exists(`${root}/${path}`).catch(() => false)) files.push(path)
  }
  const usage = withUsage ? await $.session.usage({ breakdown: 'summary' }).catch(() => undefined) : undefined
  const saved = await loadSaved($, root, plans)
  const now = await $.clock.now()
  await update($, snapshot, before => ({
    isGated: true,
    plans,
    helpers,
    files,
    context:
      usage === undefined
        ? before.context
        : { percent: usage.context.percent, tokens: usage.context.tokens, window: usage.context.window },
    details: usage === undefined ? before.details : detailsOf(usage, now),
    saved,
  }))
}

async function loadSaved($: Engine, root: string, plans: Plan[]): Promise<Saved[] | undefined> {
  const dates = plans.flatMap(plan => (plan.date === undefined ? [] : [plan.date])).sort()
  const since =
    dates[0] === undefined
      ? await $.session.usage().then(usage => new Date(usage.startedAt).toISOString(), () => undefined)
      : `${dates[0]} 00:00`
  if (since === undefined) return undefined
  const paths = KNOWLEDGE.map(([path]) => path)
  const git = (argv: string[]) =>
    $.process.run(['git', '--no-optional-locks', ...argv, '--', ...paths], { cwd: root })
  const log = await git(['log', `--since=${since}`, '--max-count=50', '--format=%h%x09%s', '--name-only']).catch(
    () => undefined,
  )
  const status = await git(['status', '--porcelain', '--untracked-files=all']).catch(() => undefined)
  if (log?.exitCode !== 0 || status?.exitCode !== 0) return undefined
  return savedRows(log.stdout, status.stdout)
}

function detailsOf(usage: SessionUsage, now: number): Details {
  const breakdown = usage.context.breakdown
  const connectors = new Map<string, number>()
  for (const tool of breakdown?.mcpTools ?? []) {
    if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(tool.serverName)) continue
    connectors.set(tool.serverName, (connectors.get(tool.serverName) ?? 0) + tool.tokens)
  }
  const limit = usage.rateLimits.find(one => one.kind === 'five_hour')
  const free = breakdown?.categories.filter(one => one.kind === 'free')
  return {
    minutes: Math.max(0, Math.floor((now - usage.startedAt) / 60000)),
    categories: (breakdown?.categories ?? [])
      .filter(one => one.kind === 'used' && one.tokens > 0)
      .map(one => ({ name: one.name, tokens: one.tokens })),
    free: free === undefined || free.length === 0 ? undefined : free.reduce((sum, one) => sum + one.tokens, 0),
    limit: limit === undefined ? undefined : { percent: limit.percentUsed, resetsAt: limit.resetsAt },
    costUsd: usage.cost?.usd,
    connectors: [...connectors].map(([name, tokens]): Tokens => ({ name, tokens })),
  }
}

async function quietly(work: () => Promise<unknown>): Promise<void> {
  try {
    await work()
  } catch {}
}

function relative(root: string, path: string): string {
  return path.startsWith(`${root}/`) ? path.slice(root.length + 1) : path
}

function steps(count: number): string {
  return count === 1 ? '1 step' : `${count} steps`
}

function running(minutes: number): string {
  return `running ${duration(minutes)}`
}

function stepCount(plan: Plan): string {
  return plan.total === 0 ? '' : ` · ${plan.done} of ${steps(plan.total)}`
}

function stageLine(plan: Plan): string {
  const stage = stageOf(plan)
  if (stage === 'Plan') return 'Plan · waiting for you to approve it'
  if (stage === 'Review and verify') return 'Review and verify · all steps built'
  const phase = plan.phases.find(one => one.done < one.total)
  return `Build${stepCount(plan)}${phase === undefined ? '' : ` · ${phase.name}`}`
}

function nextTurnLine(plan: Plan): string {
  const stage = stageOf(plan)
  if (stage === 'Plan') return 'Your next turn: approve the plan'
  const left = plan.total - plan.done
  return `Your next turn: check it works${stage === 'Build' && left > 0 ? ` · after ${left} more ${left === 1 ? 'step' : 'steps'}` : ''}`
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await quietly(async () => {
      if (!(await isGated($, await rootOf($)))) return
      await $.command.register({ name: 'progress', description: 'Show where the project stands' })
      await refresh($, true)
      void $.ui.open({ id: PANE, title: 'Progress' }).catch(() => undefined)
    })
    return next(e)
  }).catch(($, e, next) => next(e))

  on('session.end', async ($, e, next) => {
    if (e.reason === 'clear') await quietly(() => update($, turn, () => IDLE))
    return next(e)
  }).catch(($, e, next) => next(e))

  on('command.run', { command: 'progress' }, async $ => {
    if (!(await isGated($, await rootOf($)))) return { text: 'This is not a Solid Vibes project.' }
    await refresh($, true)
    await $.ui.open({ id: PANE, title: 'Progress' })
    return { text: 'Progress pane opened.' }
  })

  on('turn.start', async ($, e, next) => {
    const ran = await next(e)
    if (e.agentId === undefined) {
      await quietly(async () => {
        if (!(await isGated($, await rootOf($)))) return
        await update($, turn, before => ({ ...before, isRunning: true }))
        await refresh($, false)
      })
    }
    return ran
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const ran = await next(e)
    await quietly(async () => {
      if (!(await isGated($, await rootOf($)))) return
      if (e.agentId !== undefined) return refresh($, false, e.agentId)
      await update($, turn, before => ({ ...before, isRunning: false, lastAsk: closingParagraph(e.answer) }))
      await refresh($, true)
    })
    return ran
  }).catch(($, e, next) => next(e))

  on('tool.call', async ($, e, next) => {
    const ran = await next(e)
    if (!WRITE_TOOLS.has(String(e.tool)) || ran.deny !== undefined || ran.isError === true) return ran
    const path = 'file_path' in e ? e.file_path : 'notebook_path' in e ? e.notebook_path : undefined
    if (typeof path !== 'string') return ran
    await quietly(async () => {
      const root = await rootOf($)
      if (!(await isGated($, root))) return
      const file = relative(root, path)
      await update($, turn, before => ({
        ...before,
        recent: [...before.recent.filter(one => one !== file), file].slice(-5),
      }))
      if (file.endsWith('.md')) await refresh($, false)
    })
    return ran
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'Pane', requestId: PANE }, ($, e) => drawPane($, e, true)).catch(($, e) =>
    drawPane($, e, false),
  )
}

const TONE = { running: 'success', yourTurn: 'warning', stuck: 'error' } as const
const MUTED = '#8a8a8a'
const LINE = '#808080'
const DONE = '#2fa66a'
const WARN = '#d08a1f'
const SEGMENTS = ['#4f7ce8', '#2fa66a', '#d08a1f', '#a66ee0', '#d0567a', '#3aa6b8', '#9a8f3a']
const ICONS = {
  file: 'M14 3H6v18h12V7zM14 3v4h4',
  helper: 'M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M6 18l2.5-2.5M15.5 8.5 18 6',
  saved: 'M6 3h12v18l-6-4-6 4z',
  clock: 'M12 7v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0z',
  limit: 'M4 18a8 8 0 1 1 16 0M12 18l4-6',
  cost: 'M3 7h18v10H3zM12 10v4',
  plug: 'M9 3v5M15 3v5M7 8h10v3a5 5 0 0 1-10 0zM12 16v5',
  now: 'M3 12h4l3-8 4 16 3-8h4',
  journey: 'M6 3v18M6 4h11l-2 4 2 4H6',
  session: 'M4 18a8 8 0 1 1 16 0M12 18l4-6',
} as const

type Icon = keyof typeof ICONS
const SECTION_ICON: Record<string, Icon> = { now: 'now', journey: 'journey', saved: 'saved', files: 'file', session: 'session' }
type Segment = { name: string; tokens: number; color: string }

async function drawPane($: Engine, e: RenderInput<'Pane'>, isStyled: boolean): Promise<RenderElement> {
  const ui = $.ui.resolve(e)
  const { Box, Text, Button, Markdown } = ui
  const Svg = isStyled && 'Svg' in ui ? ui.Svg : undefined
  const snap = await read($, snapshot)
  const now = await read($, turn)
  const folded = await read($, folds)
  const open = await read($, reading)
  const openPlan = await read($, opened)

  if (!snap.isGated) return <Text dimColor>This is not a Solid Vibes project.</Text>

  if (open !== null) {
    return (
      <Box flexDirection="column">
        <Button key="back" onPress={() => update($, reading, () => null)}>
          Back
        </Button>
        <Text dimColor>{open.path}</Text>
        <Markdown text={open.text} />
      </Box>
    )
  }

  const columns = Math.max(10, e.props.bodyColumns - 2)
  const heading = isStyled ? ({ size: 'heading', weight: 'semibold', bold: true } as const) : ({ bold: true } as const)
  const picture = (source: string, alt: string, height: number, width?: number) =>
    Svg === undefined ? null : <Svg source={source} alt={alt} height={height} width={width} />
  const icon = (name: Icon) =>
    picture(
      `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="${MUTED}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="${ICONS[name]}"/></svg>`,
      name,
      14,
      14,
    )
  const divider = () =>
    Svg === undefined ? (
      <Text dimColor>{'─'.repeat(e.props.bodyColumns)}</Text>
    ) : (
      picture(
        `<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="1" preserveAspectRatio="none"><rect width="1000" height="1" fill="${LINE}" fill-opacity="0.45"/></svg>`,
        'divider',
        1,
      )
    )
  const row = (left: RenderNode, right?: string, mark?: Icon) => (
    <Box flexDirection="row" justifyContent="space-between" gap={2}>
      <Box flexDirection="row" gap={1} flexShrink={1} flexGrow={1}>
        {mark !== undefined && icon(mark)}
        <Text wrap="truncate-end">
          {left}
        </Text>
      </Box>
      {right !== undefined && right !== '' && (
        <Box flexShrink={0}>
          <Text dimColor wrap="truncate-end">
            {right}
          </Text>
        </Box>
      )}
    </Box>
  )

  const isOpen = (id: string) => isOpenIn(folded, id)
  const openFile = async (path: string) => {
    const root = await rootOf($)
    const text = (await readText($, `${root}/${path}`)) ?? 'This file could not be read.'
    const cut = text.length > READER_CAP ? `${text.slice(0, READER_CAP)}\n\nCut here; the full file is in the project.` : text
    await update($, reading, () => ({ path, text: cut }))
  }
  const toggle = (id: string, onOpen?: () => Promise<void>) => async () => {
    const after = await update($, folds, before => ({ ...before, [id]: !isOpenIn(before, id) }))
    if (after[id] === true && onOpen !== undefined) await onOpen()
  }
  const fold = (id: string, title: string, count?: string, onOpen?: () => Promise<void>) => (
    <Box flexDirection="row" justifyContent="space-between" gap={1}>
      <Box flexDirection="row" gap={1} flexShrink={1}>
        {SECTION_ICON[id] !== undefined && icon(SECTION_ICON[id])}
        <Text {...heading}>{title}</Text>
      </Box>
      <Box flexDirection="row" gap={1} flexShrink={0}>
        {count !== undefined && <Text dimColor>{count}</Text>}
        <Button key={`fold:${id}`} plain dimColor label={isOpen(id) ? '⌄' : '›'} onPress={toggle(id, onOpen)} />
      </Box>
    </Box>
  )
  const mark = (state: 'done' | 'here' | 'todo') =>
    state === 'done' ? (
      <Text color={TONE.running}>✓</Text>
    ) : state === 'here' ? (
      <Text color={TONE.yourTurn}>▸</Text>
    ) : (
      <Text dimColor>○</Text>
    )
  const planBar = (plan: Plan) => {
    const here = STAGES.findIndex(stage => stage.name === stageOf(plan))
    const total = plan.phases.reduce((sum, phase) => sum + phase.total, 0)
    const built = total === 0 ? 0 : plan.phases.reduce((sum, phase) => sum + phase.done, 0) / total
    const filled = (index: number) => (index < here ? 1 : index === here && STAGES[index]!.name === 'Build' ? built : 0)
    const label = `Stage ${here + 1} of ${STAGES.length}: ${STAGES[here]!.name}`
    if (Svg !== undefined) {
      const gap = 12
      const width = (1000 - gap * (STAGES.length - 1)) / STAGES.length
      const parts = STAGES.map((_, index) => {
        const x = index * (width + gap)
        const color = index === here ? WARN : DONE
        return `<rect x="${x.toFixed(1)}" width="${width.toFixed(1)}" height="6" rx="3" fill="${LINE}" fill-opacity="0.3"/>${
          index === here && filled(index) === 0
            ? `<rect x="${x.toFixed(1)}" width="${width.toFixed(1)}" height="6" rx="3" fill="${WARN}" fill-opacity="0.45"/>`
            : `<rect x="${x.toFixed(1)}" width="${(width * filled(index)).toFixed(1)}" height="6" rx="3" fill="${color}"/>`
        }`
      })
      return picture(
        `<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="6" preserveAspectRatio="none">${parts.join('')}</svg>`,
        label,
        6,
      )
    }
    const cell = Math.max(1, Math.floor((columns - (STAGES.length - 1)) / STAGES.length))
    return (
      <Text>
        {STAGES.map((_, index) => (
          <Text {...(index < here ? { color: TONE.running } : index === here ? { color: TONE.yourTurn } : { dimColor: true })}>
            {'━'.repeat(cell)}
            {index < STAGES.length - 1 ? ' ' : ''}
          </Text>
        ))}
      </Text>
    )
  }
  const helperRow = (helper: Helper) => row(helper.description, running(helper.minutes), 'helper')
  const stepper = (plan: Plan) => {
    const here = STAGES.findIndex(stage => stage.name === stageOf(plan))
    return STAGES.map((stage, index) => (
      <Box flexDirection="column">
        {row(
          <Text>
            {mark(index < here ? 'done' : index === here ? 'here' : 'todo')}{' '}
            <Text {...(index === here ? { bold: true } : index > here ? { dimColor: true } : {})}>{stage.name}</Text>
          </Text>,
          `${stage.by}${index === here ? ' · here' : ''}`,
        )}
        {stage.name === 'Build' &&
          plan.phases.map(phase => (
            <Box flexDirection="column" paddingLeft={2}>
              {row(
                <Text>
                  {mark(
                    index < here || (phase.done === phase.total && phase.total > 0)
                      ? 'done'
                      : phase.done > 0 || index === here
                        ? 'here'
                        : 'todo',
                  )}{' '}
                  {phase.name}
                </Text>,
                phase.total === 0 ? undefined : `${phase.done}/${phase.total}`,
              )}
            </Box>
          ))}
      </Box>
    ))
  }
  const contextBar = (segments: Segment[], window: number) => {
    if (Svg !== undefined) {
      let x = 0
      const rects = segments.map(segment => {
        const width = (segment.tokens / window) * 1000
        const rect = `<rect x="${x.toFixed(1)}" width="${width.toFixed(1)}" height="6" fill="${segment.color}"/>`
        x += width
        return rect
      })
      return picture(
        `<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="6" preserveAspectRatio="none"><rect width="1000" height="6" fill="${LINE}" fill-opacity="0.3"/>${rects.join('')}</svg>`,
        segments.map(segment => `${segment.name} ${percentOf(segment.tokens, window)}`).join(', '),
        6,
      )
    }
    let used = 0
    const parts = segments.map(segment => {
      const cells = Math.min(columns - used, Math.round((segment.tokens / window) * columns))
      used += cells
      return <Text color={segment.color}>{'━'.repeat(cells)}</Text>
    })
    return (
      <Text>
        {parts}
        <Text dimColor>{'━'.repeat(columns - used)}</Text>
      </Text>
    )
  }

  const plans = [...snap.plans].sort((a, b) => Number(stageOf(b) === 'Plan') - Number(stageOf(a) === 'Plan'))
  const needYou = plans.filter(plan => stageOf(plan) === 'Plan').length
  const working = snap.helpers.length
  const headline = now.isRunning
    ? 'Running on its own'
    : working > 0
      ? `Still working: ${working === 1 ? '1 helper' : `${working} helpers`} running`
      : 'Your turn'
  const isBusy = now.isRunning || working > 0
  const focus = plans.find(plan => stageOf(plan) === 'Plan') ?? plans.find(plan => stageOf(plan) === 'Build') ?? plans[0]
  const shown = openPlan === null ? undefined : plans.find(plan => plan.path === openPlan)
  if (shown !== undefined) {
    return (
      <Box flexDirection="column" gap={1}>
        <Button key="close-plan" plain dimColor onPress={() => update($, opened, () => null)}>
          ‹ Back
        </Button>
        <Text {...heading}>{shown.title}</Text>
        <Box flexDirection="column">
          {planBar(shown)}
          <Text dimColor size="footnote">
            {stageLine(shown)}
          </Text>
        </Box>
        {divider()}
        <Box flexDirection="column">{stepper(shown)}</Box>
        <Button key={`read:${shown.path}`} onPress={() => openFile(shown.path)}>
          Read the plan
        </Button>
      </Box>
    )
  }
  const others = snap.helpers.filter(helper => helper.plan === undefined)
  const percent = snap.context?.percent
  const firstApproved = plans.find(plan => plan.status === 'Approved')
  const details = snap.details
  const window = snap.context?.window ?? 0
  const segments: Segment[] = (
    details !== undefined && details.categories.length > 0
      ? details.categories
      : [{ name: 'Used', tokens: snap.context?.tokens ?? 0 }]
  ).map((one, index) => ({ ...one, color: SEGMENTS[index % SEGMENTS.length]! }))
  const legend = (name: string, tokens: number, color: string) =>
    row(
      <Text>
        <Text color={color}>■</Text> {name}
      </Text>,
      `${thousands(tokens)}   ${percentOf(tokens, window)}`,
    )

  return (
    <Box flexDirection="column" gap={1}>
      <Box flexDirection="column" borderStyle="round" borderColor={isBusy ? TONE.running : TONE.yourTurn} paddingX={1}>
        <Text bold color={isBusy ? TONE.running : TONE.yourTurn}>
          ● {headline}
        </Text>
        {focus === undefined ? (
          <Text>Working without a plan</Text>
        ) : (
          <Box flexDirection="column">
            {!isBusy && stageOf(focus) === 'Plan' && <Text>Approve the plan</Text>}
            <Text wrap="truncate-end" {...(!isBusy && stageOf(focus) === 'Plan' ? { dimColor: true } : {})}>
              {focus.title}
            </Text>
            {planBar(focus)}
            <Text dimColor size="footnote">
              {stageLine(focus)}
            </Text>
            {isBusy && (
              <Text dimColor size="footnote">
                {nextTurnLine(focus)}
              </Text>
            )}
          </Box>
        )}
        {!isBusy && now.lastAsk !== '' && (
          <Text dimColor size="footnote">
            {now.lastAsk}
          </Text>
        )}
        {plans.length > 1 && (
          <Text dimColor size="footnote">
            {plans.length - 1} other {plans.length === 2 ? 'plan' : 'plans'} · {needYou} {needYou === 1 ? 'needs' : 'need'} you
          </Text>
        )}
      </Box>
      {divider()}

      <Box flexDirection="column">
        {fold('journey', plans.length > 1 ? 'Open work' : 'Journey', plans.length > 1 ? String(plans.length) : undefined)}
        {isOpen('journey') && (
          <Box flexDirection="column">
            {plans.length === 0 && <Text dimColor>No open plan</Text>}
            {plans.length === 1 && stepper(plans[0]!)}
            {plans.length === 1 && snap.helpers.filter(helper => helper.plan !== undefined).map(helperRow)}
            {plans.length > 1 &&
              plans.map(plan => (
                <Box flexDirection="column">
                  <Box flexDirection="row" justifyContent="space-between" gap={1}>
                    <Box flexDirection="row" gap={1} flexShrink={1}>
                      <Text {...stageTone(plan)}>●</Text>
                      <Button key={`plan:${plan.path}`} plain onPress={() => update($, opened, () => plan.path)}>
                        {shortTitle(plan.title)}
                      </Button>
                    </Box>
                    <Box flexDirection="row" gap={1} flexShrink={0}>
                      <Text {...stageTone(plan)}>{stageChip(plan)}</Text>
                      <Text dimColor>›</Text>
                    </Box>
                  </Box>
                  {snap.helpers.filter(helper => helper.plan === plan.path).map(helperRow)}
                </Box>
              ))}
            {others.length > 0 && <Text dimColor>{plans.length === 0 ? 'Helpers' : 'Other work'}</Text>}
            {others.map(helperRow)}
            {plans.length === 0 && now.recent.length > 0 && <Text dimColor>Changed this chat</Text>}
            {plans.length === 0 && [...now.recent].reverse().map(file => row(file, undefined, 'file'))}
          </Box>
        )}
      </Box>

      {snap.saved !== undefined && divider()}
      {snap.saved !== undefined && (
        <Box flexDirection="column">
          {fold('saved', 'Saved to the project', String(snap.saved.length))}
          {isOpen('saved') && (
            <Box flexDirection="column">
              {snap.saved.length === 0 && <Text dimColor>Nothing new saved yet.</Text>}
              <Box flexDirection="column" gap={1}>
                {snap.saved.map(saved => (
                  <Box flexDirection="column">
                    {row(baseName(saved.path), saved.kind, 'saved')}
                    <Box paddingLeft={3}>
                      <Text dimColor size="footnote" wrap="truncate-end">
                        {saved.why}
                      </Text>
                    </Box>
                  </Box>
                ))}
              </Box>
            </Box>
          )}
        </Box>
      )}
      {divider()}

      <Box flexDirection="column">
        {fold('files', 'Files', String(snap.files.length))}
        {isOpen('files') && (
          <Box flexDirection="column">
            {snap.files.length === 0 && <Text dimColor>No plan, handover or intent yet.</Text>}
            {snap.files.map(path => (
              <Box flexDirection="row" gap={1}>
                {icon('file')}
                <Button key={`file:${path}`} plain onPress={() => openFile(path)}>
                  {path}
                </Button>
              </Box>
            ))}
          </Box>
        )}
      </Box>
      {divider()}

      <Box flexDirection="column">
        {fold('session', 'Session', percent === undefined ? undefined : `${percent}%`, () =>
          refresh($, true),
        )}
        {isOpen('session') && (
          <Box flexDirection="column">
            {snap.context === undefined || percent === undefined ? (
              <Text dimColor>No context reading yet.</Text>
            ) : (
              <Box flexDirection="column">
                {row(`${percent}% used`, `${thousands(snap.context.tokens ?? 0)} / ${thousands(snap.context.window)}`)}
                {contextBar(segments, window)}
                {details !== undefined && details.categories.length > 0 && segments.map(one => legend(one.name, one.tokens, one.color))}
                {details?.free !== undefined && legend('Free space', details.free, MUTED)}
              </Box>
            )}
            {percent !== undefined && percent >= 80 && (
              <Text color={TONE.yourTurn}>
                Time for a fresh start.{' '}
                {firstApproved === undefined
                  ? 'Type /clear. The handover keeps your place.'
                  : `Type /clear, then paste: go ${firstApproved.path}`}
              </Text>
            )}
            {details?.limit !== undefined &&
              row(
                'Usage limit',
                `${details.limit.percent}% of five hours${details.limit.resetsAt === undefined ? '' : ` · resets ${clockTime(details.limit.resetsAt)}`}`,
                'limit',
              )}
            {details?.costUsd !== undefined &&
              row('Cost so far', `about $${details.costUsd.toFixed(2)}`, 'cost')}
            {details !== undefined && row('Started', `${duration(details.minutes)} ago`, 'clock')}
            {details !== undefined && details.connectors.length > 0 && <Text dimColor>Connectors</Text>}
            {details?.connectors.map(one => row(one.name, thousands(one.tokens), 'plug'))}
          </Box>
        )}
      </Box>
    </Box>
  )
}

function shortTitle(title: string): string {
  const head = title.split(':')[0]!.trim()
  return head.length > 34 ? `${head.slice(0, 33).trimEnd()}…` : head
}

function stageChip(plan: Plan): string {
  const stage = stageOf(plan)
  if (stage === 'Build') return plan.total === 0 ? 'Build' : `Build ${plan.done}/${plan.total}`
  if (stage === 'Review and verify') return 'Review'
  return stage
}

function stageTone(plan: Plan): { color: 'success' | 'warning' } | { dimColor: true } {
  const stage = stageOf(plan)
  if (stage === 'Plan') return { color: 'warning' }
  if (stage === 'Build') return { color: 'success' }
  return { dimColor: true }
}

function percentOf(tokens: number, window: number): string {
  return window > 0 ? `${((tokens / window) * 100).toFixed(1)}%` : ''
}

function isOpenIn(folded: Record<string, boolean>, id: string): boolean {
  return folded[id] ?? OPEN_BY_DEFAULT[id] ?? false
}

function thousands(tokens: number): string {
  if (tokens >= 1_000_000) return `${trim(tokens / 1_000_000)}M`
  if (tokens >= 1000) return `${trim(tokens / 1000)}K`
  return String(tokens)
}

function trim(value: number): string {
  return value >= 100 ? String(Math.round(value)) : value.toFixed(1).replace(/\.0$/, '')
}

function duration(minutes: number): string {
  if (minutes < 1) return 'under a minute'
  if (minutes < 60) return `${minutes} min`
  return `${Math.floor(minutes / 60)} h ${minutes % 60} min`
}

function clockTime(iso: string): string {
  const at = new Date(iso)
  return `${String(at.getHours()).padStart(2, '0')}:${String(at.getMinutes()).padStart(2, '0')}`
}
