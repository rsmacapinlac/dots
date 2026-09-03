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

## Motion is reserved for attention

Colour, size and shape only work once you are already looking at the bar.
**Motion is the only channel that reaches you when you are not** — it is picked
up in peripheral vision, which is exactly the case "something needs you" has to
survive. That makes it the most valuable signal available, and the easiest to
destroy.

It is destroyed by spending it. If two things in the bar are moving, neither one
is urgent — they are both just animation, and the eye learns to discard them.
So:

- **Sustained motion means "this needs a response".** Nothing else may loop,
  pulse, blink, spin, or drift. Not a loading state, not a nice touch, not an
  idle flourish.
- **At most one thing moves at a time.** If a second condition could plausibly
  animate at once, one of them is not actually urgent and should say so another
  way.
- **Motion stops when the condition clears.** A permanent animation is
  decoration, and it trains you to ignore the one signal that was supposed to be
  unignorable. Bind it to the condition, not to the widget's existence.
- **Motion is never the only encoding.** The same state must also be readable
  from colour and shape, because the animation may be off-screen, occluded, or
  simply not noticed. Motion escalates a signal; it does not carry one alone.
- **Keep it slow and shallow.** A signal that has to survive peripheral vision
  needs to be smooth, not sharp. Something around a one-second cycle and a
  gentle amplitude reads as "attend to this when you can" — a fast or large
  animation reads as an alarm and becomes hostile within a minute, which is
  worse than not signalling at all.

### Transitions are not motion

State changes settling over ~120–240ms are a different thing and are not
governed by the rule above. Their job is to make a change *legible as a change*
— the eye follows a pill growing into place and knows what happened, where an
instant swap just looks like a different bar. They are bounded, caused by an
event, and over before you look.

The distinction is sustained versus transitional. A transition is triggered and
ends; motion loops until the condition clears. Only the looping kind is the
attention channel and only it is rationed.

The worked example is the workspace widget: an urgent workspace pulses on about
a 1.2s cycle at 12% scale, and stops the moment it stops being urgent. It is
also red, and also a wide labelled pill, so the pulse is escalation on top of an
already-complete signal rather than the signal itself.

## Detail is progressively disclosed

A widget shows one thing at a glance and can be asked for more. That gives it
three layers, and the discipline is entirely in what is allowed to live in
each:

1. **The glance layer** is always visible and answers the widget's questions.
   It is the widget. Everything in the sections above governs it.
2. **The hover layer** answers the *same questions*, more precisely. It is
   detail on request.
3. **The terminal** holds everything else, and is not in the bar at all.

The load-bearing rule is the one binding the second layer to the first:

**Hover may sharpen an answer the widget already gave. It may not introduce a
question the widget does not claim to answer.** The distinction is the question,
not the datum — a tooltip is free to derive, compute, or reformat, as long as
what comes out is the same question at higher resolution. The moment hovering
teaches you something the glance layer could not have told you, one of two
things is true: either that information belongs in the glance layer and is
missing from it, or it fails the test in the first section and does not belong
in the bar at all. Neither is fixed by leaving it in a tooltip.

### The cover test

Cover the tooltip and use the widget for a day.

If it still answers its questions, the disclosure is layered correctly. If you
find yourself hovering to find out where you stand, the tooltip was carrying
the answer, and the widget underneath it is broken — the tooltip was hiding
that, which is the failure worth catching, because a broken widget with a good
tooltip feels fine right up until the pointer is somewhere else.

### What the hover layer owes you

- **It is never required.** No interaction is the reading path; this is the
  detail path. This is just the rule from the first section, restated where it
  is easiest to break.
- **It waits.** A tooltip that fires instantly strobes every widget you sweep
  the pointer past on the way somewhere else. Something around 400ms means it
  only appears when you actually stopped on it.
- **It never takes focus.** A panel that steals the keyboard from the window
  underneath it is a bug on a keyboard-driven desktop, whatever it is showing.
- **It leaves when you do**, and it stays inside the screen. Bar widgets sit at
  the edges, so a tooltip centred on one will hang off the display unless it is
  told to slide back inside.
- **It says why a value is missing** rather than going blank. A tooltip with a
  gap in it reads as broken; one that says it is still estimating reads as
  working.
- **Nothing it does is destructive.** Hover fires by accident, every time.

### The worked example

The battery widget's glance layer is fill length, the colour ladder, and the
bolt: how much is left, whether that is a problem, and whether it is going up
or down. Its hover layer is `68%` and `5h 13m remaining`.

Note what that split does with the numeral. The percentage was deliberately
kept *out* of the glance layer — fill length and colour already answer "do I
need to plug in", and a digit beside them is a fourth thing to parse that
changes no decision the shape did not already prompt. But 40% and 25% are both
peach, and only one of them sends you looking for a cable. That is a precision
question, and precision is exactly what the second layer is for.

The time estimate is the same question again, in the unit you actually act on.
It is derived from a fact the glance layer never shows — the current draw rate
— and it is still legal, because it resolves "do I need to plug in?" rather
than asking something new. That is the rule doing real work: it is about the
question, not the datum.

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
  thing you occasionally want, not the thing the widget exists to tell you. See
  "Detail is progressively disclosed" above for what the hover layer owes you.
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
- [ ] Does anything here move? If so, does it mean "needs a response", is it the
      only moving thing, does it stop on its own, and is the state still
      readable without it?
- [ ] If it has a tooltip: cover it. Does the widget still answer its questions
      without it, and does the tooltip answer those same questions more
      precisely rather than smuggling in a new one?
- [ ] Does anything fire on scroll or hover that I would regret?
