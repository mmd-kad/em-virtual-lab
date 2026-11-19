# Contributing

Thanks for considering a contribution.

## Ground rules

- **Physics first.** Every displayed number must be traceable to a formula in
  [`docs/SPECIFICATION.md`](docs/SPECIFICATION.md). If you change a formula,
  add or extend a test in `tests/test_core.m` that checks it against an
  independently written closed-form expression.
- **Keep the core GUI-free.** `core/` must stay usable from the command line and
  from scripts; all plotting belongs in `gui/`.
- **ASCII only in `.m` files.** Code, comments, identifiers and GUI strings are
  English/ASCII; Persian text lives in the Markdown/PDF documentation.
- **No global variables**, and physical constants are defined only in
  `core/em_constants.m`.

## Before opening a pull request

Run all three suites and make sure they pass:

```matlab
cd tests
test_core      % must print ALL CORE TESTS PASSED (T1-T12)
smoke_gui      % must print SMOKE TEST PASSED
fuzz_probe     % must print 0 failures
```

If you touch the GUI, also regenerate the screenshots so the documentation
matches the app:

```matlab
gen_report_figures
gen_guide_figures
```

If you touch the Persian guide, rebuild it and check the glyph audit:

```bash
python tests/build_guide_tex.py
python tests/compile_guide_tex.py        # needs XeLaTeX + B Nazanin + Times New Roman
uv run --with fonttools python tests/check_guide_glyphs.py
```

The build log must contain **zero** `Missing character` warnings.

## Style

- Comment the *why*, not the *what*; every non-obvious formula gets a reference
  to the specification section it implements.
- Prefer small, named functions over long scripts.
- Report bugs with the preset or parameter set that reproduces them.
