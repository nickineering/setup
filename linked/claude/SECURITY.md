# Claude Security Settings

How this machine's Claude Code posture works, and why it is shaped this way.

## One boundary, then judgement, then a short list

One control of each kind, each doing the thing only it can do:

| Layer                    | Enforced by          | Covers                                                          |
| ------------------------ | -------------------- | --------------------------------------------------------------- |
| **Sandbox**              | the macOS kernel     | Which files and hosts a command can reach at all. Unbypassable. |
| **Auto mode classifier** | a model, per action  | Judgement: exfiltration, destructive intent, production changes |
| **`permissions.ask`**    | Claude Code's parser | A short list of operations that must always stop and ask        |
| **2 wrappers + 1 hook**  | shell scripts        | AWS credential scoping, which nothing above can express         |

### Why the hook is small

Each concern is enforced where it belongs, which leaves the hook with only AWS:

- **Filesystem and network limits** are `sandbox.filesystem` and
  `sandbox.network`. The kernel does not care how the command was spelled; a
  regex does.
- **Destructive and outbound operations** are `permissions.ask` rules. Claude
  Code parses the shell, so an ask rule matches inside `&&`, `||`, `;`, a
  subshell, a `$(...)` substitution and a `for` body, and it matches past a
  leading `FOO=bar`.
- **Judgement calls** — "is this exfiltration", "is this production" — are what
  the classifier is for. No pattern list covers them.

Regex over command text also costs more than maintenance: its false positives
train you to work around the thing meant to protect you. A pattern broad enough
to catch `rm` in a pipeline also blocks a `grep` for the literal text `.git`.

What a Bash rule cannot do is be a boundary around a _program_:
`Bash(git push *)` does not stop `git -C . push`. Anything that must hold
regardless of spelling belongs in the sandbox.

## What still asks

Two categories, on the principle that a prompt is worth it only when the
operation is hard to reverse or leaves the machine:

- **Leaves the machine:** `git push`, `glab`/`gh api` (any method), gist and
  snippet creation, terraform/cdk/sam deploys, `npm publish`, `docker push`, AWS
  mutating calls.
- **Modifies the guardrails:** the hooks, wrappers and `policy.conf` that
  enforce the rest. `settings.json` and `CLAUDE.md` need no rule — the sandbox
  write-denies them outright.

Plus `rm`, which is the most common way to lose uncommitted work. Claude Code
separately protects critical paths from `rm` in a way no allow rule can
override, including through unresolved variables and `bash -c`.

Deliberately **not** on the list, because the classifier already blocks them:
`git reset --hard`, `git checkout -- .`, `git restore .`, `git clean -fd`,
`git stash drop/clear`, `git commit --amend` on commits it did not create, force
push, `terraform destroy`, `curl | bash`, and mass cloud deletion.

## Credentials

Two layers, because they cover different callers: `permissions.deny` governs the
Read tool, and `sandbox.credentials` governs shell commands. A `denyRead` entry
does not stop the Read tool, so both lists exist.

Both match on **credential file shapes** — `.env`, `*.pem`, `*.key`, `id_rsa*`,
`credentials` — never on words. A word-shaped pattern gets this exactly
backwards: `*token*` blocks a design-system repository full of design tokens
(`tokens.json`, `terra-design-system.tokens.json`) and still misses a real token
held in the macOS keychain, where no path rule reaches.

`sandbox.credentials.envVars` unsets secret-shaped variables before each
sandboxed command. This file carries only generic names (`GH_TOKEN`,
`GITHUB_TOKEN`, `GITLAB_TOKEN`, `GLAB_TOKEN`, `NPM_TOKEN`,
`CLOUDSDK_PROXY_PASSWORD`). An employer-shaped variable belongs in the file
`TERMINATOR_EXTRA_SETTINGS` names, by the same rule as the hostnames below. If
something legitimately needs such a variable, that file is where to remove the
entry.

## Network

`sandbox.network.allowedDomains` pre-allows the hosts this machine uses. Under
auto mode an unlisted host is refused unless the command names it and the
classifier approves, so the allowlist is a convenience over a default-deny, not
a restriction added on top of an open network. Approving a host once saves a
`WebFetch(domain:...)` rule, so the list maintains itself.

Only generic hosts belong here. An employer's internal hostnames, registries,
secret-shaped environment variables and classifier context live with that
employer's own configuration instead: `TERMINATOR_EXTRA_SETTINGS` names a
settings file that terminator layers on with `--settings`, which can set
user-scope-only keys and is read whatever directory the session starts in. Read
the `"$defaults"` warning below before putting an `autoMode` list in such a file
— the two files merge, so `"$defaults"` must appear in exactly one.

Tooling that fetches its own plugins needs its host listed like any other;
`plugins.dprint.dev` is there because `dprint` re-downloads plugins whenever a
version bump invalidates its cache, and a cached copy is not something to rely
on.

`strictAllowlist` is deliberately **off**: it would turn every new host into a
hard failure and remove the self-maintaining path. Exfiltration is handled by
the classifier, which reads content and so can judge what a domain list cannot.

## Settings worth knowing, and what they cost

- `sandbox.allowUnsandboxedCommands: true` — the unsandboxed retry is available,
  and in auto mode the classifier gates it rather than it being free. It is on
  because a session cannot write the `.git` of its primary working directory,
  and without a retry an agent cannot commit, stage or merge in the repository
  it is working in. That is too high a price: `.git/hooks` and `.git/config`
  stay denied regardless, and history destruction is already covered by the
  `ask` rules and the classifier. For more strictness, exclude specific git
  write subcommands rather than disabling the retry globally.
- `sandbox.failIfUnavailable: true` — if the sandbox cannot start, nothing runs
  unsandboxed in its place.
- `autoMode.classifyAllShell: true` — every shell command is reviewed, not just
  the ones outside default approval. Costs a round-trip per command.
- `sandbox.allowAppleEvents: true` — re-opens Apple Events _inside_ the sandbox,
  which is preferable to excluding a command from it.
- `sandbox.filesystem.denyWrite` — the hooks, wrappers, `policy.conf`,
  `statusline.sh`, `terminator.sh` and `git_functions.sh`. A PreToolUse hook
  runs outside the sandbox, so writing one is an escape; `permissions.ask` on
  `Edit` does not cover it, because a shell redirection is not the Edit tool.

## Changing the posture

**`autoMode` lists replace the built-ins unless `"$defaults"` is an entry.**
Writing `"hard_deny": ["..."]` silently deletes every built-in classifier rule —
all the git, exfiltration and force-push protection above — with no error. Every
`autoMode` list in `settings.json` leads with `"$defaults"` for this reason.

To add a rule, pick the layer by what the rule needs to be true:

| Need                                     | Where it goes                      |
| ---------------------------------------- | ---------------------------------- |
| Must hold regardless of command spelling | `sandbox.filesystem` / `.network`  |
| Should stop and ask, every time          | `permissions.ask`                  |
| Depends on intent or content             | `autoMode.hard_deny` / `soft_deny` |
| Needs state the above cannot see         | `hooks/validate-command.sh`        |

Write a `Bash(cmd*)` rule, not `Bash(cmd *)`: the spaced form needs a trailing
argument and so misses a bare invocation.

After editing, run `claude doctor` — it lists entries Claude Code rejected,
which is the only way to notice a key that is silently doing nothing. `/sandbox`
shows the resolved boundary and `/status` the settings sources in effect. Hook
changes need a test in `tests/validate-command.bats`.
