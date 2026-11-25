import type { Phase, Plan, PlanStatus, Saved } from './progress-pane-state'

export const STAGES = [
  { name: 'Plan', by: 'you' },
  { name: 'Build', by: 'AI' },
  { name: 'Review and verify', by: 'AI' },
  { name: 'Check it works', by: 'you' },
  { name: 'Release', by: 'you' },
] as const

export type Stage = (typeof STAGES)[number]['name']

const STATUS: Record<string, PlanStatus | null> = {
  draft: 'Draft',
  'not-started': 'Approved',
  approved: 'Approved',
  implemented: 'Implemented',
  deferred: 'Deferred',
  idea: null,
}

const OWNER_ONLY = /only the user|owner-only|\(you\)/i

export function plansFolder(agentsMd: string | undefined): string | undefined {
  const line = /^- \*\*plans\*\* — (.*)$/m.exec(agentsMd ?? '')?.[1]
  const token = line === undefined ? undefined : /`([^`]+)`/.exec(line)?.[1]
  if (token === undefined || /^none\b/.test(line ?? '')) return undefined
  return token.endsWith('/') ? token : token.slice(0, token.lastIndexOf('/') + 1) || undefined
}

function statusOf(text: string): PlanStatus | null {
  const body = /^\*\*Status(?:\*\*:|:\*\*)\s*([\w-]+)/m.exec(text)?.[1]?.toLowerCase()
  const frontmatter = /^---\n([\s\S]*?)\n---/.exec(text)?.[1] ?? ''
  const front = /^status:\s*([\w-]+)/m.exec(frontmatter)?.[1]?.toLowerCase()
  return STATUS[body ?? ''] ?? STATUS[front ?? ''] ?? null
}

export function parsePlan(path: string, text: string): Plan | undefined {
  const status = statusOf(text)
  if (status === null) return undefined
  const title = (/^# (.*)$/m.exec(text)?.[1] ?? path).replace(/^Plan:\s*/i, '').trim()
  const date = /^\*\*Date\*\*:\s*(\d{4}-\d{2}-\d{2})\b/m.exec(text)?.[1]
  const phases: Phase[] = []
  let phase: { level: number; phase: Phase } | undefined
  let isVerification = false
  let isFenced = false
  let done = 0
  let total = 0
  for (const line of text.split('\n')) {
    if (/^\s*(```|~~~)/.test(line)) isFenced = !isFenced
    if (isFenced) continue
    const heading = /^(#{2,6})\s+(.*)$/.exec(line)
    if (heading !== null) {
      const level = heading[1]!.length
      const name = heading[2]!.trim()
      if (level === 2) isVerification = /^verification\b/i.test(name)
      if (phase !== undefined && level <= phase.level) phase = undefined
      if (level <= 3 && /^phase\b/i.test(name)) {
        phase = { level, phase: { name, done: 0, total: 0 } }
        phases.push(phase.phase)
      }
      continue
    }
    const step = /^\s*- \[([ xX])\]/.exec(line)
    if (step === null || isVerification || OWNER_ONLY.test(line)) continue
    const isDone = step[1] !== ' '
    total += 1
    done += isDone ? 1 : 0
    if (phase !== undefined) {
      phase.phase.total += 1
      phase.phase.done += isDone ? 1 : 0
    }
  }
  return { path, title, date, status, done, total, phases }
}

export function stageOf(plan: Plan): Stage {
  if (plan.status === 'Draft') return 'Plan'
  return plan.total > 0 && plan.done === plan.total ? 'Review and verify' : 'Build'
}

export function closingParagraph(text: string): string {
  const last = text.trim().split(/\n\s*\n/).at(-1)?.trim() ?? ''
  return last.length > 240 ? `${last.slice(0, 239)}…` : last
}

export const KNOWLEDGE: readonly (readonly [string, string])[] = [
  ['AGENTS.md', 'Rule'],
  ['docs/intent.md', 'Intent'],
  ['docs/stack.md', 'Stack'],
  ['docs/decisions/', 'Decision'],
  ['docs/how-it-works/', 'How it works'],
  ['docs/design/', 'Design'],
  ['.agents/skills/', 'Skill'],
]

function kindOf(path: string): string | undefined {
  return KNOWLEDGE.find(([prefix]) => (prefix.endsWith('/') ? path.startsWith(prefix) : path === prefix))?.[1]
}

export function savedRows(log: string, status: string): Saved[] {
  const rows: Saved[] = []
  const add = (path: string, why: string) => {
    const kind = kindOf(path)
    if (kind !== undefined && !rows.some(row => row.path === path)) rows.push({ path, kind, why })
  }
  for (const line of status.split('\n')) {
    if (line.length > 3) add(line.slice(3).split(' -> ').at(-1)!, 'Not saved in git yet')
  }
  let subject = ''
  for (const line of log.split('\n')) {
    if (line.includes('\t')) subject = line.slice(line.indexOf('\t') + 1)
    else if (line.trim() !== '') add(line.trim(), subject)
  }
  return rows.slice(0, 8)
}
