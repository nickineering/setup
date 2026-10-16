#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.13"
# dependencies = ["pyautogui>=0.9.54"]
# ///
"""Keep the display awake and prevent inactivity timeouts.

Nudges the pointer a pixel and back on a fixed interval. That resets the display
idle timer much like `caffeinate` does, and unlike `caffeinate` it registers as
real user input, so it works on all apps.

Needs Accessibility permission for the terminal running it (System Settings >
Privacy & Security > Accessibility).
"""

import signal
import sys
from time import sleep

INTERVAL_SECONDS = 60

# The ⚠ line and these codes are lib/colors.sh's warn(), so a message from here
# looks like one from the shell scripts in this repo.
YELLOW = "\033[33m"
DIM = "\033[38;5;245m"
RESET = "\033[0m"

# Signals that land while pyautogui is importing are recorded here rather than
# acted on. That import costs about a second of pyobjc loading, so a Ctrl-C in
# the window is easy to hit, and pyautogui's macOS backend wraps its
# `import Quartz` in a bare `except:` - which catches KeyboardInterrupt and
# SystemExit alike and re-raises them as a misleading "you must first install
# pyobjc-core and pyobjc" AssertionError. Recording rather than raising keeps
# anything catchable out of the import; the check below still honours the
# keypress instead of dropping it, just a beat later.
interrupted: list[int] = []


def note_interrupt(signum: int, _frame: object) -> None:
    """Remember a signal, to be acted on once the import below finishes."""
    interrupted.append(signum)


def exit_quietly(signum: int) -> None:
    """Exit with the shell's 128+N code, leaving the cursor at column 0."""
    # On Ctrl-C the tty echoes "^C" with no newline of its own, so exiting here
    # would leave the shell mid-line - zsh flags that with a reverse-video "%"
    # at the next prompt (PROMPT_SP, on by default). Ending on a newline is what
    # every well-behaved program does. Only a terminal cares and only SIGINT
    # echoes, so redirected output and `kill` stay byte-for-byte unchanged.
    if signum == signal.SIGINT and sys.stdout.isatty():
        sys.stdout.write("\n")
    sys.stdout.flush()
    # sys.exit, not os._exit: dying instantly makes uv lose a race with its own
    # child and print "error: Failed to get PID of child process". Unwinding
    # normally is quiet, and slow enough for uv to keep up.
    sys.exit(128 + signum)  # 128+N is the shell's convention for "killed by N"


def quiet_exit(signum: int, _frame: object) -> None:
    """Stop on Ctrl-C or `kill` without spilling a traceback."""
    # One-shot. A terminal signals the whole process group and uv forwards to
    # its child on top of that, so the same signal arrives twice. The second
    # delivery lands during interpreter shutdown, where raising SystemExit is
    # reported as "Exception ignored on threading shutdown" - a traceback again.
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    exit_quietly(signum)


signal.signal(signal.SIGINT, note_interrupt)
signal.signal(signal.SIGTERM, note_interrupt)

import pyautogui  # Deliberately imported after the handlers above, not at top

if interrupted:
    exit_quietly(interrupted[0])

signal.signal(signal.SIGINT, quiet_exit)
signal.signal(signal.SIGTERM, quiet_exit)


def nudge() -> None:
    """Move the pointer one pixel and straight back, leaving it where it was."""
    x, y = pyautogui.position()
    # A pixel left is on screen everywhere but the left edge, where right is.
    # Going right first instead would land off screen at the right edge, where
    # macOS clamps the move back to the starting pixel and nothing moves.
    pyautogui.moveTo(x - 1 if x > 0 else x + 1, y)
    pyautogui.moveTo(x, y)


def report_failsafe() -> None:
    """Say what happened and what to do, where a traceback reads as a crash."""
    stopped = "awake stopped: the pointer is in a screen corner, which means stop."
    fix = "Move it out of the corner and run awake again."
    # Colour a terminal only; in a pipe or a file the codes would be junk.
    warn, dim, reset = (YELLOW, DIM, RESET) if sys.stderr.isatty() else ("", "", "")
    print(f"{warn}⚠ {stopped}{reset}", file=sys.stderr)
    print(f"{dim}  {fix}{reset}", file=sys.stderr)


def main() -> None:
    """Nudge on a loop until a signal stops us; quiet_exit does the exiting."""
    # Silent in normal operation, like caffeinate: nothing to report until it is
    # stopped, and no output means nothing to interleave with whatever else is
    # using the terminal.
    while True:
        try:
            nudge()
        except pyautogui.FailSafeException:
            report_failsafe()
            sys.exit(1)
        sleep(INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
