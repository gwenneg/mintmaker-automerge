#!/usr/bin/env node
// Evals for the setup skill.
//
// Each fixture under fixtures/ is a small Konflux-onboarded repository. The
// driver copies it to a temp dir, runs `/mintmaker-automerge:setup` through
// the Agent SDK, and plays the user from the fixture's expect.json: every
// AskUserQuestion menu is answered with its "(Recommended)" option unless
// the file says otherwise, and Step 10 picks "Stop here" unless the file
// says "Commit on a branch", so nothing ever leaves the machine. The
// transcript and the written files are then checked against expect.json.
//
// Usage: node run.mjs [fixture...] [--serial] [--keep]
// Needs a Claude credential the CLI can use: a claude.ai login, or
// CLAUDE_CODE_OAUTH_TOKEN from `claude setup-token`, or ANTHROPIC_API_KEY.
//
// expect.json:
//   repo                 owner/name behind the fake origin URL
//   defaultBranchKnown   whether origin/HEAD is set, so Step 1 needs no branch question
//   stops                true for a repo the skill must stop on: no menu, the stop message, nothing written
//   menus                the menu calls in order, each a list of question headers;
//                        "*" stands for one or more follow-up calls with headers the skill does not name
//   answers              header -> answer: a label substring, {labels: [...]} for a multi-select,
//                        {text: "..."} for a typed reply, {sequence: [...]} when the header comes back
//   followups            [{match: regex on "header question", answer}] for the questions of a follow-up call,
//                        one whose first header the skill does not name; never applied to a prescribed menu
//   files                path -> {exists, contains: [...], lacks: [...]} checked after the run
//   config               the Renovate config path: parsed as JSON5 (a superset of JSONC); configContains and
//                        configLacks are matched against the parsed document re-serialised as compact JSON,
//                        whitespace ignored, so comments, quoting style and formatting do not matter
//   validatorConfig      the config path the validator workflow must name (default: the config path)
//   validatorFiles       exact number of workflow files that call the validator action (default: at least one)
//   textContains         substrings the model's text must contain, case-insensitive

import { query } from "@anthropic-ai/claude-agent-sdk";
import JSON5 from "json5";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

// A Claude Code session running this script would otherwise silence the
// nested CLI the SDK spawns.
for (const k of Object.keys(process.env)) {
  if (/^(CLAUDECODE$|CLAUDE_CODE_(ENTRYPOINT|CHILD_SESSION|SESSION_ID|MESSAGING|BRIDGE))/.test(k)) delete process.env[k];
}
// The fixtures point at repositories that do not exist: git must fail fast rather than ask for a login.
process.env.GIT_TERMINAL_PROMPT = "0";

const here = path.dirname(fileURLToPath(import.meta.url));
const pluginDir = process.env.PLUGIN_DIR ? path.resolve(process.env.PLUGIN_DIR) : path.resolve(here, ".."); // PLUGIN_DIR: another checkout, for A/B runs
const fixturesDir = path.join(here, "fixtures");
const args = process.argv.slice(2);
const keep = args.includes("--keep");
const serial = args.includes("--serial");
const names = args.filter((a) => !a.startsWith("--"));
const selected = (names.length ? names : fs.readdirSync(fixturesDir)).filter((n) =>
  fs.existsSync(path.join(fixturesDir, n, "expect.json")),
).sort();
if (selected.length === 0) {
  console.error("no fixture selected");
  process.exit(2);
}
const resultsDir = path.join(here, "results", `${new Date().toISOString().replace(/[:.]/g, "-")}-${process.pid}`); // pid: parallel runs must not share a directory
fs.mkdirSync(resultsDir, { recursive: true });

// The step a menu belongs to, from the header of its first question.
// "Never automerge" and "Majors" are never first, so they need no entry.
const STEP_OF = {
  Ecosystems: 1, "Default branch": 1,
  Rename: 2, Location: 2,
  Scope: 3,
  "Pin actions": 4, "Allow-list": 4,
  "Base images": 5, "Pin base images": 5, Wrappers: 5,
  Pipeline: 6, "Go indirect": 6, "npm PRs": 6,
  "Base image workflow": 7, Dependabot: 7,
  "Write it": 8,
  Checks: 9, Bypass: 9,
  "Ship it": 10,
};
// A prescribed menu opens with one of these headers, after its step header has been printed. A follow-up
// (names to type, per-ecosystem scopes) opens with a header of the model's choosing, which may collide with
// a prescribed one, so a call whose step header has not been printed yet counts as a follow-up.
const stepOf = (headers, stepsSeen) => {
  const n = STEP_OF[headers[0]];
  return n !== undefined && stepsSeen.has(n) ? n : undefined;
};
// After these answers the reply may legitimately open with something other
// than the next step header: Step 6 ends with its two notes and a closing
// line, Step 8 goes on with the write phase, the Checks answer brings the
// bypass screen or an explanation, and Step 10 is the end.
const NO_HEADER_AFTER_STEP = new Set([6, 8, 10]);
const STOP_MESSAGE = "🛑 No `.tekton/` folder with Konflux markers";

const git = (cwd, ...a) =>
  execFileSync("git", a, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();

function makeRepo(name, expect) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), `mm-eval-${name}-`));
  fs.cpSync(path.join(fixturesDir, name), dir, { recursive: true });
  fs.rmSync(path.join(dir, "expect.json"));
  git(dir, "init", "-q", "-b", "main");
  git(dir, "add", "-A");
  git(dir, "-c", "user.name=eval", "-c", "user.email=eval@example.com", "commit", "-q", "-m", "fixture");
  git(dir, "remote", "add", "origin", `https://github.com/${expect.repo}.git`);
  if (expect.defaultBranchKnown) {
    git(dir, "update-ref", "refs/remotes/origin/main", "HEAD");
    git(dir, "remote", "set-head", "origin", "main");
  }
  return dir;
}

// --- the scripted user
const label = (q, s) => q.options.find((o) => o.label.includes(s))?.label ?? s; // no match: it is a typed reply
function resolve(q, spec) {
  if (typeof spec === "string") return label(q, spec);
  if (spec.text !== undefined) return spec.text;
  if (spec.labels) return spec.labels.map((s) => label(q, s)).join(", ");
  throw new Error(`bad answer spec for ${q.header}: ${JSON.stringify(spec)}`);
}
function answerFor(q, expect, state, followUp) {
  let spec = expect.answers?.[q.header];
  if (spec === undefined && followUp) {
    for (const f of expect.followups ?? []) {
      if (new RegExp(f.match, "i").test(`${q.header} ${q.question}`)) { spec = f.answer; break; }
    }
  }
  if (spec !== undefined && spec.sequence) {
    const i = state[q.header] ?? 0;
    state[q.header] = i + 1;
    spec = spec.sequence[Math.min(i, spec.sequence.length - 1)];
  }
  if (spec !== undefined) return resolve(q, spec);
  const recommended = q.options.filter((o) => /\(Recommended\)/.test(o.label));
  if (recommended.length) return (q.multiSelect ? recommended : [recommended[0]]).map((o) => o.label).join(", ");
  return q.options[0].label;
}

const squash = (s) => s.replace(/\s+/g, "");

// expected menus vs the menus seen: "*" eats one or more calls with unnamed headers
function menusMatch(expected, got) {
  let i = 0;
  for (const e of expected) {
    if (e === "*") {
      let n = 0;
      while (i < got.length && got[i].followUp) { i++; n++; }
      if (n === 0) return false;
    } else {
      if (i >= got.length || [...e].sort().join("+") !== [...got[i].headers].sort().join("+")) return false;
      i++;
    }
  }
  return i === got.length;
}
const showMenus = (m) => m.map((e) => (e === "*" ? "*" : [...(e.headers ?? e)].sort().join("+"))).join(" → ");

async function runFixture(name) {
  const expect = JSON.parse(fs.readFileSync(path.join(fixturesDir, name, "expect.json"), "utf8"));
  expect.answers = { "Ship it": "Stop here", ...(expect.answers ?? {}) };
  const commits = /Commit on a branch/.test(typeof expect.answers["Ship it"] === "string" ? expect.answers["Ship it"] : "");
  const repo = makeRepo(name, expect);
  const fixtureCommit = git(repo, "rev-parse", "HEAD");
  const transcript = fs.createWriteStream(path.join(resultsDir, `${name}.jsonl`));
  const lines = [];
  const log = (s) => lines.push(s);
  const trace = []; // {kind:"text"} | {kind:"menu"} | {kind:"tool"}
  const failures = [];
  const check = (ok, msg) => { if (!ok) failures.push(msg); };
  const state = {};
  const stepsSeen = new Set(); // step headers printed so far
  let statusAtWriteIt = null;
  let result = null;
  const abort = new AbortController();
  const timer = setTimeout(() => abort.abort(), (expect.timeoutMinutes ?? 20) * 60_000);

  console.log(`[${name}] started`);
  try {
    for await (const m of query({
      prompt: "/mintmaker-automerge:setup",
      options: {
        cwd: repo,
        plugins: [{ type: "local", path: pluginDir }],
        settingSources: [],
        maxTurns: 100,
        abortController: abort,
        canUseTool: async (tool, input) => {
          if (tool !== "AskUserQuestion") return { behavior: "allow", updatedInput: input };
          const answers = {};
          const followUp = stepOf(input.questions.map((q) => q.header), stepsSeen) === undefined;
          for (const q of input.questions) {
            if (q.header === "Write it") statusAtWriteIt = git(repo, "status", "--porcelain");
            answers[q.question] = answerFor(q, expect, state, followUp);
            log(`        [user] ${q.header}: ${answers[q.question]}`);
          }
          return { behavior: "allow", updatedInput: { questions: input.questions, answers } };
        },
      },
    })) {
      transcript.write(JSON.stringify(m) + "\n");
      if (m.type === "assistant") {
        for (const b of m.message.content) {
          if (b.type === "text") {
            for (const m of b.text.matchAll(/### ▶️ Step (\d+)\/10/g)) stepsSeen.add(Number(m[1]));
            trace.push({ kind: "text", text: b.text });
            const head = b.text.match(/^###.*$/m)?.[0] ?? b.text.split("\n")[0];
            log(`[text] ${head.slice(0, 100)} (${b.text.length} chars)`);
          } else if (b.type === "tool_use" && b.name === "AskUserQuestion" && !(b.input.questions ?? []).every((q) => q.header && q.options)) {
            log(`[malformed menu] ${JSON.stringify(b.input).slice(0, 120)}`); // rejected by the tool before anyone sees it
          } else if (b.type === "tool_use" && b.name === "AskUserQuestion") {
            const headers = b.input.questions.map((q) => q.header);
            const step = stepOf(headers, stepsSeen);
            trace.push({ kind: "menu", headers, step, followUp: step === undefined });
            log(`[menu] ${headers.join(" | ")}`);
          } else if (b.type === "tool_use") {
            trace.push({ kind: "tool", name: b.name });
            log(`[tool] ${b.name}${b.name === "Bash" ? " " + String(b.input.command ?? "").slice(0, 90) : ""}`);
          }
        }
      } else if (m.type === "result") {
        result = m;
        log(`[result] ${m.subtype} turns=${m.num_turns} cost≈$${(m.total_cost_usd ?? 0).toFixed(2)}`);
      }
    }
  } catch (e) {
    failures.push(`run error: ${e.message}`);
  } finally {
    clearTimeout(timer);
    transcript.end();
  }

  // --- the conversation
  const allText = trace.filter((t) => t.kind === "text").map((t) => t.text).join("\n");
  const menus = trace.filter((t) => t.kind === "menu");
  check(result?.subtype === "success", `result: ${result?.subtype ?? "none"}`);
  const denials = result?.permission_denials ?? [];
  check(denials.length === 0, `permission denials: ${denials.map((d) => d.tool_name).join(", ")}`);
  const firstText = trace.find((t) => t.kind === "text")?.text ?? "";
  check(firstText.trimStart().startsWith("### 🤖 MintMaker Automerge Setup"), "the first text is not the welcome screen");
  for (const s of expect.textContains ?? []) check(allText.toLowerCase().includes(s.toLowerCase()), `the text never says ${JSON.stringify(s)}`);

  if (expect.stops) {
    check(menus.length === 0, `a menu was asked on a repo the skill must stop on: ${menus.map((m) => m.headers.join("|")).join(", ")}`);
    check(allText.includes("### ▶️ Step 1/10"), "Step 1/10 header missing");
    check(allText.includes(STOP_MESSAGE), "the stop message was not printed");
    check(!trace.some((t) => t.kind === "tool" && (t.name === "Write" || t.name === "Edit")), "a Write or Edit happened on a repo the skill must stop on");
    check(git(repo, "status", "--porcelain") === "", "the working tree was touched");
  } else {
    let pos = -1;
    for (let n = 1; n <= 10; n++) {
      const i = allText.indexOf(`### ▶️ Step ${n}/10`, pos + 1);
      check(i > pos, `Step ${n}/10 header missing or out of order`);
      if (i > pos) pos = i;
    }
    check(menusMatch(expect.menus, menus), `menus differ\n        expected: ${showMenus(expect.menus)}\n        got:      ${showMenus(menus)}`);
    for (let i = 0; i < trace.length; i++) {
      const t = trace[i];
      if (t.kind !== "menu") continue;
      const lbl = t.headers.join("|");
      const before = [];
      for (let j = i - 1; j >= 0 && trace[j].kind !== "menu"; j--) if (trace[j].kind === "text") before.unshift(trace[j].text);
      if (!t.followUp) {
        // a follow-up may come right after its step's menu, with no screen of its own
        check(before.length > 0, `menu ${lbl} came with no text since the previous menu`);
        if (t.headers[0] === "Bypass") {
          check(before.join("\n").includes("**The Konflux app bypass**"), "the Bypass menu came without the bypass screen");
        } else if (t.step && !(t.headers[0] === "Checks" && menus.filter((m) => m.headers[0] === "Checks").indexOf(t) > 0)) {
          check(before.some((x) => x.includes(`### ▶️ Step ${t.step}/10`)), `menu ${lbl} came without the Step ${t.step}/10 screen before it`);
        }
      }
      const next = trace.slice(i + 1).find((x) => x.kind !== "tool");
      const nextMenu = trace.slice(i + 1).find((x) => x.kind === "menu");
      const followUpNext = nextMenu?.followUp; // a line introducing a follow-up is not a transition
      if (next?.kind === "text" && !followUpNext && !NO_HEADER_AFTER_STEP.has(t.step) && t.headers[0] !== "Checks") {
        check(/^### ▶️ Step \d+\/10/.test(next.text.trimStart()), `after the ${lbl} answer the reply does not open with the next step header`);
      }
    }
    const writeIt = trace.findIndex((t) => t.kind === "menu" && t.headers[0] === "Write it");
    check(writeIt > 0, "the Write it menu never came");
    if (writeIt > 0) {
      check(trace.slice(0, writeIt).some((t) => t.kind === "text" && t.text.includes("| Ecosystem |")), "the Step 8 summary table was not printed before the Write it menu");
      check(!trace.slice(0, writeIt).some((t) => t.kind === "tool" && (t.name === "Write" || t.name === "Edit")), "a Write or Edit happened before the Write it answer");
      check(statusAtWriteIt === "", `the working tree was already dirty at the Write it menu: ${statusAtWriteIt}`);
    }

    // --- the repository
    const branches = git(repo, "branch", "--list").split("\n").filter(Boolean);
    if (commits) {
      check(branches.length === 2, `expected one new branch, found: ${branches.join(", ")}`);
      check(git(repo, "rev-parse", "main") === fixtureCommit, "main moved despite 'Commit on a branch'");
      check(git(repo, "rev-parse", "--abbrev-ref", "HEAD") !== "main", "still on main despite 'Commit on a branch'");
      check(git(repo, "rev-list", "--count", "HEAD") === "2", "expected exactly one commit on the new branch");
      check(git(repo, "status", "--porcelain") === "", "files left uncommitted despite 'Commit on a branch'");
    } else {
      check(git(repo, "status", "--porcelain") !== "", "nothing was written to the working tree");
      check(git(repo, "rev-list", "--count", "HEAD") === "1", "a commit was made despite 'Stop here'");
      check(branches.length === 1, "a branch was created despite 'Stop here'");
    }
    for (const [f, want] of Object.entries(expect.files ?? {})) {
      const p = path.join(repo, f);
      const exists = fs.existsSync(p);
      if (want.exists !== undefined) check(exists === want.exists, want.exists ? `${f} was not written` : `${f} still exists`);
      if (!exists) continue;
      let raw = fs.readFileSync(p, "utf8");
      if (/\.ya?ml$/.test(f)) raw = raw.split("\n").filter((l) => !/^\s*#/.test(l)).join("\n"); // comments may name what was removed
      for (const s of want.contains ?? []) check(raw.includes(s), `${f} lacks ${JSON.stringify(s)}`);
      for (const s of want.lacks ?? []) check(!raw.includes(s), `${f} still contains ${JSON.stringify(s)}`);
    }
    if (expect.config) {
      const cfgPath = path.join(repo, expect.config);
      check(fs.existsSync(cfgPath), `${expect.config} was not written`);
      if (fs.existsSync(cfgPath)) {
        const raw = fs.readFileSync(cfgPath, "utf8");
        fs.copyFileSync(cfgPath, path.join(resultsDir, `${name}.${path.basename(expect.config)}`));
        let body = ""; // the rules without comments, quoting or formatting differences
        try { body = squash(JSON.stringify(JSON5.parse(raw))); } catch (e) { check(false, `${expect.config} does not parse: ${e.message}`); }
        for (const s of expect.configContains ?? []) check(body.includes(squash(s)), `${expect.config} lacks ${JSON.stringify(s)}`);
        for (const s of expect.configLacks ?? []) check(!body.includes(squash(s)), `${expect.config} still contains ${JSON.stringify(s)}`);
        check(!/<[a-z-]+>|\{\{/.test(raw), `${expect.config} has an unfilled placeholder`);
      }
    }
    const wfDir = path.join(repo, ".github/workflows");
    const validators = fs.existsSync(wfDir)
      ? fs.readdirSync(wfDir).map((f) => fs.readFileSync(path.join(wfDir, f), "utf8")).filter((t) => t.includes("konflux-ci/renovate-config-validator-action"))
      : [];
    if (expect.validatorFiles !== undefined) check(validators.length === expect.validatorFiles, `expected ${expect.validatorFiles} validator workflow(s), found ${validators.length}`);
    else check(validators.length >= 1, "no validator workflow was added");
    const vcfg = expect.validatorConfig ?? expect.config;
    if (vcfg && validators.length) check(validators.some((t) => t.includes(vcfg)), `no validator workflow names ${vcfg}`);
  }

  if (keep) log(`[keep] ${repo}`); else fs.rmSync(repo, { recursive: true, force: true });
  fs.writeFileSync(path.join(resultsDir, `${name}.log`), lines.join("\n") + "\n");
  console.log(`[${name}] ${failures.length ? "FAIL" : "PASS"} (${result?.num_turns ?? "?"} turns)`);
  return { name, failures, lines, turns: result?.num_turns, cost: result?.total_cost_usd };
}

const reports = [];
if (serial) for (const n of selected) reports.push(await runFixture(n));
else reports.push(...(await Promise.all(selected.map(runFixture))));

let failed = 0;
for (const r of reports) {
  console.log(`\n=== ${r.name}: ${r.failures.length ? "FAIL" : "PASS"} · ${r.turns ?? "?"} turns · ≈$${(r.cost ?? 0).toFixed(2)}`);
  for (const l of r.lines) console.log("  " + l);
  for (const f of r.failures) console.log("  ✗ " + f);
  if (r.failures.length) failed++;
}
console.log(`\n${reports.length - failed}/${reports.length} fixtures passed · transcripts in ${path.relative(process.cwd(), resultsDir)}`);
process.exit(failed ? 1 : 0);
