export type PlanStatus = 'Draft' | 'Approved' | 'Implemented' | 'Deferred'

export type Phase = { name: string; done: number; total: number }

export type Plan = {
  path: string
  title: string
  date?: string
  status: PlanStatus
  done: number
  total: number
  phases: Phase[]
}

export type Helper = { id: string; description: string; minutes: number; plan?: string }

export type Context = { percent?: number; tokens?: number; window: number }

export type Snapshot = {
  isGated: boolean
  plans: Plan[]
  helpers: Helper[]
  files: string[]
  context?: Context
}

export type Turn = { isRunning: boolean; lastAsk: string; recent: string[] }

export type Reading = { path: string; text: string }

declare module 'claude-code' {
  interface PluginState {
    sv: {
      snapshot: Shaped<Snapshot>
      turn: Shaped<Turn>
      folds: Shaped<Record<string, boolean>>
      reading: Shaped<Reading | null>
    }
  }
}
