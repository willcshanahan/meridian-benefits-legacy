# Modernization Backlog

Fictional system, fictional agency. See `README.md`.

Candidate migration order, most important first. The golden file suite in
`tests/` is the acceptance gate for every item: a migrated module must reproduce
`data/golden/expected/` byte for byte before it is considered equivalent.

| # | Module | Effort | Risk if deferred | Gate |
|---|--------|--------|------------------|------|
| 1 | MBA100 `ELIGCALC` | medium | high — nobody left who can explain the paragraph order | `ELIG.DAT`, `ELIGCALC.AUD` byte exact |
| 2 | MBA200 `BENEFITS` | medium | high — rounding semantics are undocumented outside the code | `BENEFIT.DAT`, `BENEFITS.AUD` byte exact |
| 3 | MBA300 `PAYCALC` | low | medium — warrant seeding is operationally fragile | `PAYMENT.DAT`, `PAYCALC.AUD` byte exact |
| 4 | MBA400 `REPTGEN` | low | low — presentation only | `REGISTER.TXT` byte exact |
| 5 | `WSCONST.CPY` constants to a parameter file | low | medium — every rate change is a recompile | full suite after a no-op parameter load |
| 6 | Interface files to a documented schema | high | medium — external consumers are unknown | full suite plus consumer sign off |

## 1. MBA100 `ELIGCALC` — migrate first

**Rationale.**

* **It is the source of every downstream number.** The determination record
  decides eligibility, band, countable income and eligible days. If MBA100 is
  right, the other three modules are arithmetic and formatting. If it is wrong,
  every later module is confidently wrong in the same direction. Migrating it
  first means the highest value behaviour is under a modern test harness on day
  one instead of last.
* **It holds the most undocumented policy.** Roughly fifteen years of statute
  changes were expressed as edits to the order of the paragraphs, not as
  comments. The 1990 disability disregard move — ahead of the income band test,
  backed out once, then reinstated — is the clearest example: it changed about
  400 awards and exists nowhere but the code. That knowledge decays fastest and
  is the most expensive to reconstruct after the last maintainer leaves.
* **It is the best shaped unit of work.** One input file, two output files, no
  control card, no sort dependency, no print formatting. Its `PROCEDURE
  DIVISION` is under 200 lines, so a reimplementation can be reviewed side by
  side against the original by someone who does not read COBOL fluently.
* **It produces the strictest possible test.** The determination file is a
  fixed 80 byte record with no dates, no sequence numbers and no host
  dependencies, so byte equality is achievable and meaningful. That makes MBA100
  the ideal place to prove the migration pattern — extract, reimplement, diff
  against golden — before spending it on a module where equality is harder to
  assert.
* **It de-risks everything after it.** Once determinations are produced by a
  modern component, MBA200 through MBA400 can be migrated one at a time behind
  the same file interfaces, with the legacy modules still available to run in
  parallel for a cycle.

**Approach.** Reimplement MBA100 against `CLAIMANT.CPY` and `ELIG-RECORD`
exactly as written, including the `FILLER` and the trailing blanks. Run the new
module in the harness in place of the compiled `ELIGCALC` and require
`ELIG.DAT` and `ELIGCALC.AUD` to compare byte exact. Do not "fix" anything
observed along the way — the referral override in `2700-AWARD-CLAIM` and the
`I05` denial before banding both look like bugs and are both current policy.
File them as separate policy items for Program Policy to rule on.

## 2. MBA200 `BENEFITS`

Second because the rounding contract is the second largest body of hidden
behaviour: `ROUNDED` on the income offset, the deliberate double `COMPUTE` for
the proration, `COMP-3` intermediates, and the `BN-ROUND-IND` flag that feeds a
state report. Any language whose default is banker's rounding or binary floating
point will fail `MB1000105 ESTERBROOK` immediately, which is exactly why that
fixture exists. Migrate with an explicit decimal type and half-up rounding.

## 3. MBA300 `PAYCALC`

Low effort, moderate operational value. The installment split is a truncating
divide with the odd penny on installment 1, and the warrant seed comes from the
control card rather than from state. Migrating it is a chance to move the seed
into a durable sequence and remove the stale card failure mode — but the
sequence must still be seedable, or the golden files cannot be reproduced.

## 4. MBA400 `REPTGEN`

Presentation only, and the least risky thing in the system: a control break, a
county name table, a 20 line page depth and fixed column positions. Deliberately
last, because rewriting the report first is tempting, visible, and moves none of
the actual risk. Keep the 132 column output until the county offices agree to a
new format; their reconciliation procedures reference the column positions.

## 5. Constants to a parameter file

The 1984 design note promised this "next fiscal year". Doing it after MBA100 and
MBA200 are migrated means the parameter load can be tested by asserting that a
no-op parameter set reproduces the golden files exactly, which is a much
stronger test than reviewing a table by eye.

## 6. Interface files to a documented schema

Blocked, not deferred: the determination file layout is read by a county extract
job outside this repository, and the owner list is not current. Requires a
consumer inventory before any field can move. Until then, `FILLER` is the only
place new data goes.
