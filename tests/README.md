# Golden File Test Harness

Fictional system, fictional data. See the repository `README.md`.

## Running

```sh
./tests/run_golden_tests.sh
```

The harness compiles the four modules with GnuCOBOL, then runs the same five
steps as `jcl/NIGHTLY.JCL` and byte compares every output against
`data/golden/expected/`:

| Step | Module | Outputs asserted |
|------|--------|------------------|
| `ELIGSTEP` | MBA100 `ELIGCALC` | `ELIG.DAT`, `ELIGCALC.AUD` |
| `BENESTEP` | MBA200 `BENEFITS` | `BENEFIT.DAT`, `BENEFITS.AUD` |
| `PAYSTEP`  | MBA300 `PAYCALC`  | `PAYMENT.DAT`, `PAYCALC.AUD` |
| `SORTSTEP` | `sort` in place of DFSORT | `PAYSORT.DAT` |
| `REPTSTEP` | MBA400 `REPTGEN`  | `REGISTER.TXT` |

DD names are resolved through `DD_<ddname>` environment variables, so the step
definitions in the script line up with the DD cards in the JCL. Work files land
in `build/work/`, load modules in `build/load/`; both are disposable.

## Rebaselining

```sh
./tests/run_golden_tests.sh --rebaseline
```

A rebaseline overwrites the expected files. It is a policy decision, not a build
step. Rebaseline only when a change to a constant in `WSCONST.CPY` or to a rule
has been approved by Program Policy, and commit the regenerated expected files
in the same commit as the code change with the approval reference in the message.
Never rebaseline to make a red suite green.

## Fixture coverage — `data/golden/input/CLAIMANT.DAT`

36 claimant records. The interesting ones:

| Case | Covers |
|------|--------|
| `MB1000101` | plain full month award, no dependents, band 1 |
| `MB1000103` | countable income exactly at the household limit — eligible |
| `MB1000104` | one cent over the limit — denied `I05` |
| `MB1000105` | **rounding case**, see below |
| `MB1000107` | residency below minimum, no prior claim — denied `R02` |
| `MB1000108` | residency below minimum with prior claim — referred `R09` |
| `MB1000109` | disability lowers the residency minimum — eligible |
| `MB1000111` | closed case — denied `C11` |
| `MB1000112` | suspended case — referred `C14` |
| `MB1000113` | pending status, extra review points |
| `MB1000114` | county code not on the table — denied `E09` |
| (blank id) | missing case id — denied `E01` |
| `MB1000116` | eligibility starts on day 30, one eligible day, award falls under `WC-MIN-WARRANT` — suppressed `M` |
| `MB1000117` | eligibility starts on day 2, 29 day proration |
| `MB1000118` | large income with the maximum dependent disregard — still denied `I05` |
| `MB1000119` | 13 dependents — denied `E07` |
| `MB1000120` | 12 dependents, review score over threshold — referred |
| `MB1000122` | at the dependent adjusted limit — eligible |
| `MB1000123` | one cent over the dependent adjusted limit, disregard pulls it back |
| `MB1000124` | disability disregard drives countable income to zero |
| `MB1000125` | zero income |
| `MB1000129` | four dependents plus proration, rounding adjustment |
| `MB1000130` | 24 day proration, rounding adjustment |
| `MB1000133` | tiny income, 3 eligible days |
| `MB1000136` | mid month start, rounding adjustment |

Determination mix produced by the suite: 14 full month eligible, 10 partial
month, 5 referred, 7 denied, 1 suppressed under the minimum warrant, and
4 records carrying `BN-ROUND-IND = 'R'`.

## The COBOL specific rounding case

`MB1000105 ESTERBROOK` exists to pin `COMP-3` and `ROUNDED` semantics, and any
reimplementation that uses binary floating point or banker's rounding fails it.

```
monthly income                            1294.00
less dependent disregard (1 x 60.00)        60.00
countable income                          1234.00

income offset  1234.00 x 0.333 = 410.9220
  COMPUTE WS-OFFSET ROUNDED   ->            410.92   (half up, not 410.92200)

gross  742.50 + 128.75 - 410.92 =           460.33
eligible days (starts day 16)                    15

460.33 x 15 / 30 = 230.165
  COMPUTE WS-NET-ROUNDED ROUNDED  ->        230.17
  COMPUTE WS-NET-TRUNCATED        ->        230.16
  the two disagree  ->  BN-ROUND-IND = 'R'

MBA300 split:  230.17 / 2 = 115.085 truncated -> 115.08
               installment 1 = 230.17 - 115.08 = 115.09
```

So the claimant is paid `115.09` then `115.08`, the register subtotal ties to
`230.17`, and the truncated `230.16` is never paid — it only sets the flag.

## Known emulation differences from the host

* Files are `ORGANIZATION LINE SEQUENTIAL` here, so trailing blanks are stripped
  on write. On the host the same records are `RECFM=FB` and blank padded to 80
  (or 132). The comparison is still byte exact against a baseline produced the
  same way; do not "fix" the fixtures by padding them.
* `SORTSTEP` uses `LC_ALL=C sort` in place of DFSORT. The key positions match
  `SORT FIELDS=(10,3,CH,A,1,9,CH,A)` and `LC_ALL=C` is required for the
  collating sequence to hold.
* The print file has no ASA carriage control byte, matching the 1988 print
  subsystem change noted in `REPTGEN`.
