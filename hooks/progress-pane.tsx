import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import { STAGES, closingParagraph, parsePlan, plansFolder, stageOf } from './progress-pane-parse'
import type { Stage } from './progress-pane-parse'
import type { Helper, Plan, Snapshot, Turn } from './progress-pane-state'

type Engine = EngineInterface

const PANE = 'sv-progress'
const MANIFEST = '.solidvibes/manifest.json'
const KEPT_FILES = ['.solidvibes/handover.md', 'docs/intent.md']
const WRITE_TOOLS = new Set(['Edit', 'Write', 'MultiEdit', 'NotebookEdit'])
const ENDED = new Set(['completed', 'failed', 'killed'])
const OPEN_BY_DEFAULT: Record<string, boolean> = { now: true, journey: true }
const READER_CAP = 20000

const EMPTY: Snapshot = { isGated: false, plans: [], helpers: [], files: [] }
const IDLE: Turn = { isRunning: false, lastAsk: '', recent: [] }

const snapshot = atom({ plugin: 'sv', key: 'snapshot' } as const, EMPTY, { shape: 'snapshot-1' })
const turn = atom({ plugin: 'sv', key: 'turn' } as const, IDLE, { shape: 'turn-1' })
const folds = atom({ plugin: 'sv', key: 'folds' } as const, {}, { shape: 'folds-1' })
const reading = atom({ plugin: 'sv', key: 'reading' } as const, null, { shape: 'reading-1' })

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

async function loadHelpers($: Engine, plans: Plan[]): Promise<Helper[]> {
  const agents = await $.agent.list().catch(() => [])
  const now = await $.clock.now()
  return agents
    .filter(agent => !ENDED.has(agent.status))
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

async function refresh($: Engine, withUsage: boolean): Promise<void> {
  const root = await rootOf($)
  if (!(await isGated($, root))) {
    await update($, snapshot, () => EMPTY)
    return
  }
  const plans = await loadPlans($, root)
  const helpers = await loadHelpers($, plans)
  const files: string[] = []
  for (const path of [...plans.map(plan => plan.path), ...KEPT_FILES]) {
    if (await $.fs.exists(`${root}/${path}`).catch(() => false)) files.push(path)
  }
  const usage = withUsage ? await $.session.usage().catch(() => undefined) : undefined
  await update($, snapshot, before => ({
    isGated: true,
    plans,
    helpers,
    files,
    context: usage === undefined ? before.context : usage.context,
  }))
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
  return minutes < 1 ? 'running under a minute' : `running ${minutes} min`
}

function stageLine(plan: Plan): string {
  const stage = stageOf(plan)
  if (stage === 'Plan') return 'Plan · waiting for you to approve it'
  if (stage === 'Review and verify') return 'Review and verify · all steps built'
  const phase = plan.phases.find(one => one.done < one.total)
  return `Build · ${plan.done} of ${steps(plan.total)}${phase === undefined ? '' : ` · ${phase.name}`}`
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
    if (e.agentId === undefined) {
      await quietly(async () => {
        if (!(await isGated($, await rootOf($)))) return
        await update($, turn, before => ({ ...before, isRunning: false, lastAsk: closingParagraph(e.answer) }))
        await refresh($, true)
      })
    }
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
      await refresh($, false)
    })
    return ran
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button, Markdown } = $.ui.resolve(e)
    const snap = await read($, snapshot)
    const now = await read($, turn)
    const folded = await read($, folds)
    const open = await read($, reading)

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

    const isOpen = (id: string) => isOpenIn(folded, id)
    const toggle = (id: string, onOpen?: () => Promise<void>) => async () => {
      const after = await update($, folds, before => ({ ...before, [id]: !isOpenIn(before, id) }))
      if (after[id] === true && onOpen !== undefined) await onOpen()
    }
    const header = (id: string, title: string, onOpen?: () => Promise<void>) => (
      <Button key={`fold:${id}`} plain onPress={toggle(id, onOpen)}>
        {isOpen(id) ? '▾' : '▸'} {title}
      </Button>
    )
    const helperRow = (helper: Helper) => (
      <Text>
        {'  '}
        {helper.description} <Text dimColor>· {running(helper.minutes)}</Text>
      </Text>
    )
    const stepper = (plan: Plan) => {
      const here = STAGES.findIndex(stage => stage.name === stageOf(plan))
      return STAGES.map((stage, index) => (
        <Box flexDirection="column">
          <Text>
            {index < here ? '✓' : index === here ? '▸' : '○'} {stage.name}{' '}
            <Text dimColor>
              · {stage.by}
              {index === here ? ' · here' : ''}
            </Text>
          </Text>
          {stage.name === 'Build' &&
            plan.phases.map(phase => (
              <Text>
                {'    '}
                {phase.done === phase.total ? '✓' : phase.done > 0 || index === here ? '▸' : '○'} {phase.name}{' '}
                <Text dimColor>
                  · {phase.done} of {steps(phase.total)}
                </Text>
              </Text>
            ))}
        </Box>
      ))
    }

    const plans = [...snap.plans].sort(
      (a, b) => Number(stageOf(b) === 'Plan') - Number(stageOf(a) === 'Plan'),
    )
    const needYou = plans.filter(plan => stageOf(plan) === 'Plan').length
    const working = snap.helpers.length
    const headline = now.isRunning
      ? 'Running on its own'
      : working > 0
        ? `Still working: ${working === 1 ? '1 helper' : `${working} helpers`} running`
        : 'Your turn'
    const isBusy = now.isRunning || working > 0
    const others = snap.helpers.filter(helper => helper.plan === undefined)
    const percent = snap.context?.percent
    const firstApproved = plans.find(plan => plan.status === 'Approved')

    return (
      <Box flexDirection="column">
        {header('now', 'Now')}
        {isOpen('now') && (
          <Box flexDirection="column" paddingLeft={2}>
            <Text bold>{headline}</Text>
            {!isBusy && now.lastAsk !== '' && <Text dimColor>{now.lastAsk}</Text>}
            {plans.length > 1 && (
              <Text>
                {plans.length} open · {needYou} {needYou === 1 ? 'needs' : 'need'} you
              </Text>
            )}
            {plans.map(plan => (
              <Text>
                {plan.title} <Text dimColor>· {stageLine(plan)}</Text>
              </Text>
            ))}
            {isBusy && plans.length === 1 && <Text>{nextTurnLine(plans[0]!)}</Text>}
          </Box>
        )}

        {header('journey', plans.length > 1 ? 'Open work' : 'Journey')}
        {isOpen('journey') && (
          <Box flexDirection="column" paddingLeft={2}>
            {plans.length === 0 && <Text>Working without a plan</Text>}
            {plans.length === 1 && stepper(plans[0]!)}
            {plans.length === 1 && snap.helpers.filter(helper => helper.plan !== undefined).map(helperRow)}
            {plans.length > 1 &&
              plans.map(plan => (
                <Box flexDirection="column">
                  {header(`plan:${plan.path}`, `${plan.title} · ${stageOf(plan)} · ${plan.done} of ${steps(plan.total)}`)}
                  {snap.helpers.filter(helper => helper.plan === plan.path).map(helperRow)}
                  {isOpen(`plan:${plan.path}`) && (
                    <Box flexDirection="column" paddingLeft={2}>
                      {stepper(plan)}
                    </Box>
                  )}
                </Box>
              ))}
            {others.length > 0 && <Text>{plans.length === 0 ? 'Helpers' : 'Other work'}</Text>}
            {others.map(helperRow)}
            {plans.length === 0 && now.recent.length > 0 && <Text>Changed this chat</Text>}
            {plans.length === 0 &&
              [...now.recent].reverse().map(file => (
                <Text dimColor>
                  {'  '}
                  {file}
                </Text>
              ))}
          </Box>
        )}

        {header('files', 'Files')}
        {isOpen('files') && (
          <Box flexDirection="column" paddingLeft={2}>
            {snap.files.length === 0 && <Text dimColor>No plan, handover or intent yet.</Text>}
            {snap.files.map(path => (
              <Button
                key={`file:${path}`}
                plain
                onPress={async () => {
                  const root = await rootOf($)
                  const text = (await readText($, `${root}/${path}`)) ?? 'This file could not be read.'
                  const cut =
                    text.length > READER_CAP
                      ? `${text.slice(0, READER_CAP)}\n\nCut here; the full file is in the project.`
                      : text
                  await update($, reading, () => ({ path, text: cut }))
                }}
              >
                {path}
              </Button>
            ))}
          </Box>
        )}

        {header('session', percent === undefined ? 'Session' : `Session · ${percent}% context`, () =>
          refresh($, true),
        )}
        {isOpen('session') && (
          <Box flexDirection="column" paddingLeft={2}>
            {snap.context === undefined || percent === undefined ? (
              <Text dimColor>No context reading yet.</Text>
            ) : (
              <Text>
                {percent}% of the context used{' '}
                <Text dimColor>
                  · {thousands(snap.context.tokens ?? 0)} of {thousands(snap.context.window)} tokens
                </Text>
              </Text>
            )}
            {percent !== undefined && percent >= 80 && (
              <Text>
                Time for a fresh start.{' '}
                {firstApproved === undefined
                  ? 'Type /clear. The handover keeps your place.'
                  : `Type /clear, then paste: go ${firstApproved.path}`}
              </Text>
            )}
          </Box>
        )}
      </Box>
    )
  })
}

function isOpenIn(folded: Record<string, boolean>, id: string): boolean {
  return folded[id] ?? OPEN_BY_DEFAULT[id] ?? false
}

function thousands(tokens: number): string {
  return tokens >= 1000 ? `${Math.round(tokens / 1000)}k` : String(tokens)
}
