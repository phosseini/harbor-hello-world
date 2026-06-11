# harbor-hello-world

[Harbor](https://github.com/harbor-framework/harbor) is a framework for
running and grading AI agents on tasks inside isolated Docker containers.
This repo is a minimal Harbor task — `kidney-function-calc` — used as a
hands-on intro to how Harbor builds, runs, and grades agent tasks.

The task itself is small on purpose: given a short clinical vignette, an
agent must compute a creatinine clearance (Cockcroft-Gault) and write the
number to a file. That keeps the focus on *how Harbor works* rather than on
the task content.

## Prerequisites

- **Docker Desktop**, installed and running (`docker info` should succeed)
- **Harbor CLI** — install with `uv tool install harbor` (requires
  [uv](https://docs.astral.sh/uv/))
- An **API key** for at least one LLM provider (OpenAI, Anthropic, etc.),
  depending on which agent/model you want to run

## Setup

1. Clone this repo and `cd` into it.
2. Copy the env template and fill in your key(s):

   ```bash
   cp .env.example .env
   ```

   Edit `.env` and set whichever provider key(s) you plan to use, e.g.:

   ```
   OPENAI_API_KEY=sk-...
   ANTHROPIC_API_KEY=sk-ant-...
   ```

   `.env` is gitignored — never commit real keys. `harbor run --env-file .env`
   loads this file and forwards the relevant key(s) to the agent based on the
   model you select.

## Quick start

### 1. Sanity check (no LLM, free)

Run the task's reference solution (`kidney-function-calc/solution/solve.sh`)
via Harbor's built-in `oracle` agent. This doesn't call any model — it just
confirms the environment and verifier are wired up correctly:

```bash
harbor run -p kidney-function-calc -a oracle --env-file .env
```

You should see `Mean: 1.000` — a perfect score.

### 2. Run a real agent

```bash
harbor run -p kidney-function-calc -a terminus-2 -m openai/gpt-5.4-mini-2026-03-17 --env-file .env
```

Swap `-a` (agent) and `-m` (model) for any combination Harbor supports — see
`harbor run --help` for the full list of agents.

### 3. Inspect results

```bash
harbor view jobs
```

Each run writes a timestamped folder under `jobs/` containing the trial
transcript, the agent's final files, and the reward.

## How a Harbor task run works

Every Harbor task is just a folder with five pieces:

| File | Role |
|---|---|
| `task.toml` | Task config: name, timeouts, network mode, OS, etc. |
| `instruction.md` | The prompt given to the agent |
| `environment/Dockerfile` | Defines the sandbox the agent works in |
| `solution/solve.sh` | A reference ("oracle") solution — used for sanity checks |
| `tests/test.sh` | The verifier — grades whatever the agent produced |

A single `harbor run` goes through these steps:

1. **Build** — Harbor builds a Docker image from `environment/Dockerfile`
   (cached after the first run).
2. **Start** — A container is started from that image. With
   `network_mode = "public"`, it has normal internet access.
3. **Agent setup** — The chosen agent prepares its environment. For a
   terminal-driven agent like `terminus-2`, this means installing any tools
   it needs (`tmux`, `asciinema`) and opening a terminal session inside the
   container.
4. **Agent run loop** — `instruction.md` is sent to the model as the initial
   prompt. From there it's a loop:
   - the model (running on your host machine, called via its API) responds
     with a shell command,
   - Harbor runs that command inside the container and captures the output,
   - the output is fed back to the model,
   - repeat until the model finishes or the timeout is hit.

   The agent is expected to leave its answer in a known location —
   for this task, `/app/answer.txt`.
5. **Verify** — `tests/test.sh` is uploaded into the container and run. It
   reads `/app/answer.txt`, checks it against the expected value, and writes
   `1` or `0` to `/logs/verifier/reward.txt`.
6. **Collect results** — Harbor downloads the reward and trial transcript
   into `jobs/<timestamp>/<task>__<id>/`, then tears down the container.

**The `oracle` agent is a shortcut through steps 3–4**: instead of calling a
model, it uploads `solution/solve.sh` and runs it directly to produce
`/app/answer.txt`. Same verifier, same reward — useful for confirming the
task is graded correctly before spending any API credits on a real agent.

```
instruction.md ──▶ [agent loop: LLM ⇄ shell commands in container] ──▶ /app/answer.txt
                                  (or: oracle runs solve.sh)
                                                                              │
                                                                              ▼
                                                                tests/test.sh ──▶ reward.txt
```

## Project structure

```
.
├── .env.example              # template for API keys (copy to .env)
├── kidney-function-calc/      # the Harbor task
│   ├── task.toml              # config: name, timeouts, network mode, OS
│   ├── instruction.md          # prompt given to the agent
│   ├── environment/
│   │   └── Dockerfile          # the agent's sandbox
│   ├── solution/
│   │   └── solve.sh            # reference solution (used by `-a oracle`)
│   └── tests/
│       └── test.sh             # verifier: grades the agent's answer
└── jobs/                       # run output (gitignored)
```
