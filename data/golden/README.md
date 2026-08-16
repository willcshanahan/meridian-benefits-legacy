# Golden Files

Fictional claimants, fictional counties, invented figures. Nothing here came
from a real case file.

```
input/CLAIMANT.DAT    36 record claimant master extract, 80 byte fixed
input/PAYCYCLE.CTL    cycle control card - cycle 199807, installment days 05
                      and 20, method W, warrant seed 0004100
expected/             baselined outputs, one per step of the nightly cycle
```

`expected/` is written only by `tests/run_golden_tests.sh --rebaseline` and a
rebaseline needs Program Policy approval — see `tests/README.md`.

Column positions for `input/CLAIMANT.DAT` are documented in
`docs/ARCHITECTURE.md`; the authority is `src/copybooks/CLAIMANT.CPY`.
