# Quickshell Widget Design

This document governs what a bar widget is allowed to show and how it may be
interacted with. It is about design, not code — the module layout, the
`BarWidget` contract, and the `Colors`/`Theme` split live in `AGENTS.md`.

The bar is looked at hundreds of times a day and read almost never. Every rule
below follows from that.

## The principle: glance-able

**A widget earns its place in the bar by answering one or two questions at a
glance.**

"At a glance" is a strict test, not a figure of speech. It means the answer
arrives from colour, position, or shape before any text is read. If you have to
focus on the widget and parse it to know the answer, the widget has failed, no
matter how much it displays.

Three consequences:

1. **Name the questions before writing the widget.** If the questions cannot be
   stated in one line each, the widget is not ready to be built. Workspaces, for
   example, answers:
   - Which workspace is this screen on?
   - Which workspace wants attention?

2. **Anything that does not serve those questions competes with them.** A widget
   is not improved by adding a field. Extra detail is not free — it dilutes the
   thing you actually put the widget there for.

3. **Information you would never act on does not belong in the bar.** If knowing
   it would not change what you do next, it is telemetry, not a widget. Put it
   behind a command you run when you actually want it.

## States compete for legibility

A widget communicates by making states *distinguishable*. Each additional state
it tries to distinguish makes every other state harder to pick out, because the
available signals — colour, brightness, size, shape — are shared and finite.

So:

- **Two states may be strong. Everything else recedes.** The strong states are
  the answers to the widget's questions; the rest is context and should be quiet
  enough that it never competes.
- **Do not encode a state the questions did not ask for.** A state that answers
  no question is spending legibility for nothing.
- **A question with no encoding is a bug.** If a widget claims to answer "which
  workspace wants attention" and urgency is not visible, the widget does not do
  its job, however good it looks.

The failure mode to watch for is a widget that encodes several states weakly —
several shades of the same colour, several opacities — so that all of them
require reading and none of them glance.

## Interaction rules

**No interaction is ever required to read a widget.** Interaction is a shortcut
to an action, never the way information is revealed. A widget whose answer is
only visible on hover or click has failed the glance test by definition.

Given that:

- **Click performs the obvious action for the primary question.** On workspaces,
  the primary question is "which workspace am I on", so click switches to one.
  If there is no obvious action, the widget does not need a click handler.
- **Right-click and scroll are secondary and optional.** They may offer a faster
  path to something, but never the only path — the same thing must be reachable
  without them. Prefer the terminal-first tool that already does the job over
  building a second interface into the bar.
- **Hover may add detail; it may not carry the answer.** A tooltip is for the
  thing you occasionally want, not the thing the widget exists to tell you.
- **Nothing destructive on scroll or hover.** These fire by accident. Anything
  that logs out, disconnects, kills a process, or cannot be undone belongs
  behind a deliberate click, and usually behind a confirmation.

## Checklist for a new widget

Before writing one:

- [ ] What one or two questions does this answer? Write them down.
- [ ] Would knowing this change what I do next? If not, it is not a widget.
- [ ] Which two states are strong? What recedes?
- [ ] Does every stated question have a visible encoding?
- [ ] Is the widget fully readable with no interaction at all?
- [ ] Does anything fire on scroll or hover that I would regret?
