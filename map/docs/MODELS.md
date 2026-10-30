# Loaded model details

The model presenter shows the captured table, primary key, base/STI labels,
columns and named associations in Source and Links. Missing source is explicit;
model details remain useful on the source-unavailable page. Targets are labels,
through/polymorphic targets can be unknown, and scopes/default expressions are
never evaluated. Database defaults are distinct from Ruby attribute defaults.

The pane consumes `rails_model` facts with model metadata version 1. It escapes
all labels/defaults/options and limits display to 200 rows per family and 256 KiB
of encoded model metadata. Display truncation is explicit; the Reader fact API
retains the full admitted evidence. Existing generation-preserving navigation,
authorization, keyboard focus and no-JavaScript routes remain in use.

This component is new Thistle presentation code using existing Map styles; no
additional Woods code or assets were copied. Existing attribution remains in
[REUSE.md](REUSE.md). The [component contract](https://github.com/lost-in-the/thistle/blob/main/docs/development/loaded-model-evidence.md)
records the required shared-view adapter and outstanding integrated checks.
