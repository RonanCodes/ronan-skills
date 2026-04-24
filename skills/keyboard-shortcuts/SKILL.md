---
name: keyboard-shortcuts
description: Wire a global keyboard shortcut handler with editable-element and modifier guards, plus a discoverable help dialog. Power-user signal that pays for itself in demos, screencasts, and portfolio respect. Use on any utility app with more than three primary actions.
category: quality-review
argument-hint: [--actions <file>] [--help-key ?] [--no-dialog]
allowed-tools: Bash(*) Read Write Edit Glob Grep
---

# Keyboard Shortcuts

A small amount of keyboard wiring changes how an app feels. Arrow keys to navigate, `?` for a help overlay, bindings for the 3-5 most-common actions. Takes 30 minutes, reads as craft.

## Usage

```
/ro:keyboard-shortcuts                    # wire defaults (arrows, ?, common verbs)
/ro:keyboard-shortcuts --help-key h       # use 'h' instead of '?' for help
/ro:keyboard-shortcuts --no-dialog        # skip the help overlay, just wire bindings
```

## What gets wired

1. **`src/hooks/useKeyboardShortcuts.ts`** — single global handler with proper guards.
2. **`src/components/ShortcutsDialog.tsx`** — Radix or headless dialog listing bindings.
3. **Integration in the top-level app** (or route) calling `useKeyboardShortcuts(actions)`.
4. **Optional discovery hint** — small footer text `Press ? for shortcuts.`

## 1. The hook

```ts
// src/hooks/useKeyboardShortcuts.ts
import { useEffect } from 'react'

export interface Shortcut {
  key: string | string[]       // e.g. 'ArrowLeft' or ['t', 'T']
  description: string          // shown in the help dialog
  handler: (e: KeyboardEvent) => void
  allowInInputs?: boolean      // default false — skip if user typing
}

function isEditable(el: Element | null): boolean {
  if (!el) return false
  const tag = el.tagName
  if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return true
  if ((el as HTMLElement).isContentEditable) return true
  return false
}

export function useKeyboardShortcuts(
  shortcuts: Shortcut[],
  opts?: { enabled?: boolean },
) {
  useEffect(() => {
    if (opts?.enabled === false) return

    const handler = (e: KeyboardEvent) => {
      // Never hijack browser shortcuts.
      if (e.metaKey || e.ctrlKey || e.altKey) return

      const shortcut = shortcuts.find((s) => {
        const keys = Array.isArray(s.key) ? s.key : [s.key]
        return keys.includes(e.key)
      })
      if (!shortcut) return

      if (!shortcut.allowInInputs && isEditable(document.activeElement)) return

      e.preventDefault()
      shortcut.handler(e)
    }

    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [shortcuts, opts?.enabled])
}
```

**Why a single handler, not many `addEventListener` calls scattered around?**
- One place to debug when a shortcut stops firing.
- Easy to disable globally (e.g. during a modal).
- One place to enforce the editable-element + modifier guards.
- The shortcut list doubles as the help-dialog data source.

## 2. The help dialog

Use whatever dialog primitive the app already has (Radix, Headless UI, shadcn). The content is a static table from the same `shortcuts` array.

```tsx
// src/components/ShortcutsDialog.tsx
import * as Dialog from '@radix-ui/react-dialog'
import type { Shortcut } from '@/hooks/useKeyboardShortcuts'

export function ShortcutsDialog({
  open,
  onOpenChange,
  shortcuts,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  shortcuts: Shortcut[]
}) {
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 bg-black/50" />
        <Dialog.Content className="fixed left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 bg-white p-6 rounded-lg shadow-lg max-w-md w-full">
          <Dialog.Title className="text-lg font-semibold mb-4">
            Keyboard shortcuts
          </Dialog.Title>
          <dl className="space-y-2">
            {shortcuts.map((s) => (
              <div key={s.description} className="flex justify-between gap-4">
                <dt>{s.description}</dt>
                <dd className="font-mono text-sm">
                  {(Array.isArray(s.key) ? s.key : [s.key]).map((k) => (
                    <kbd
                      key={k}
                      className="px-2 py-0.5 bg-gray-100 border border-gray-300 rounded"
                    >
                      {prettyKey(k)}
                    </kbd>
                  ))}
                </dd>
              </div>
            ))}
          </dl>
          <Dialog.Close className="mt-4 text-sm text-gray-500">Close (Esc)</Dialog.Close>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  )
}

function prettyKey(k: string): string {
  const map: Record<string, string> = {
    ArrowLeft: '←',
    ArrowRight: '→',
    ArrowUp: '↑',
    ArrowDown: '↓',
    Escape: 'Esc',
    Enter: '↵',
  }
  return map[k] ?? k
}
```

## 3. Wiring it up

```tsx
// src/App.tsx or src/routes/__root.tsx
import { useState } from 'react'
import { useKeyboardShortcuts } from '@/hooks/useKeyboardShortcuts'
import { ShortcutsDialog } from '@/components/ShortcutsDialog'

export function App() {
  const [shortcutsOpen, setShortcutsOpen] = useState(false)

  const shortcuts = [
    { key: ['ArrowLeft', ','], description: 'Previous day', handler: goToPreviousDay },
    { key: ['ArrowRight', '.'], description: 'Next day', handler: goToNextDay },
    { key: ['t', 'T'], description: 'Go to today', handler: goToToday },
    { key: ['h', 'H'], description: 'Toggle hints', handler: toggleHints },
    { key: ['s', 'S'], description: 'Settings', handler: () => setSettingsOpen(true) },
    { key: '?', description: 'Show this help', handler: () => setShortcutsOpen(true) },
  ]

  useKeyboardShortcuts(shortcuts)

  return (
    <>
      {/* ...app */}
      <ShortcutsDialog
        open={shortcutsOpen}
        onOpenChange={setShortcutsOpen}
        shortcuts={shortcuts}
      />
    </>
  )
}
```

## Picking the right bindings

**Do bind:**
- Arrow keys for navigation (prev/next day, prev/next item, up/down in a list).
- Single-letter verbs for the 3-5 most common actions (`t` for today, `h` for hint, `s` for settings, `/` for search focus).
- `?` or `h` for the help dialog — whichever your app doesn't already use.
- `Esc` for close modals / clear selection — usually handled by Radix out of the box, but verify.

**Don't bind:**
- Any `Cmd+X` / `Ctrl+X` combo. You'll clash with browser shortcuts (copy, save, new tab). Leave those alone.
- Letters used as first-letter abbreviations for proper nouns in the UI. If "t" in-page means "Twitter", repurposing it as "today" is confusing.
- Shortcuts that aren't discoverable. Every binding must appear in the help dialog. Secret ones are liability, not feature.

## Best-practice patterns

- **Always guard against editable elements.** Users typing "t" in a search box should not jump to today.
- **Always skip modifier keys.** `Cmd+←` is browser back. Never preventDefault it.
- **Preserve the browser's built-in shortcuts.** `/` traditionally focuses search — map your app's search to that instead of coming up with something novel.
- **`?` is the de-facto help key.** GitHub, Gmail, Linear, Notion all use it. Don't invent a new one.
- **Keep the list short.** 5-8 bindings is the sweet spot. 20+ bindings means nobody remembers any.
- **Discovery matters.** A footer line like `Press ? for shortcuts` converts the feature from invisible to visible. Without it, nobody knows.

## Accessibility

Pairs with `/ro:accessibility-ci`. Keyboard shortcuts are one half of keyboard accessibility; the other half is standard tab-order navigation, visible focus rings, and `aria-keyshortcuts`:

```tsx
<button aria-keyshortcuts="t" onClick={goToToday}>Today</button>
```

`aria-keyshortcuts` is announced by screen readers when they focus the button, so users with assistive tech discover your bindings.

## Testing

Playwright is excellent for this — deterministic key events:

```ts
// tests/keyboard.spec.ts
test('arrow keys navigate days', async ({ page }) => {
  await page.goto('/')
  const originalDate = await page.locator('[data-test="puzzle-date"]').textContent()
  await page.keyboard.press('ArrowLeft')
  const newDate = await page.locator('[data-test="puzzle-date"]').textContent()
  expect(newDate).not.toBe(originalDate)
})

test('shortcuts ignored in inputs', async ({ page }) => {
  await page.goto('/')
  await page.locator('[data-test="search-input"]').focus()
  await page.keyboard.press('t')
  // Should not have jumped to today — search value should be 't'
  await expect(page.locator('[data-test="search-input"]')).toHaveValue('t')
})
```

## Gotchas

- **`keydown` vs `keypress`.** Use `keydown`. `keypress` is deprecated and doesn't fire for non-character keys like arrows.
- **React 18 StrictMode double-invokes effects.** Attach/detach twice in dev is fine — just don't put side effects (like `alert`) in the setup path.
- **iOS Safari doesn't fire keydown on most keys.** Mobile browsers with on-screen keyboards emit synthetic events that lose modifier state. Don't rely on keyboard shortcuts on mobile; they're a desktop power-user feature.
- **Event listener on `document` vs `window`.** `window` is better — catches events even when focus is in an iframe you embed.

## See also

- `/ro:app-polish` — umbrella; this is check #6
- `/ro:accessibility-ci` — complementary `aria-keyshortcuts` + focus-ring work
- `/ro:posthog` — track which shortcuts actually get used (`feature_used` with `shortcut` field)
- Shortcut convention reference: https://shortcutwiki.com/
