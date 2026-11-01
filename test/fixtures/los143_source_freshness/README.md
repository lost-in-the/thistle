# LOS143 installed Core source-freshness cards

**AUTHORED UNRUN.** These scripts require Root's later finite runtime admission.
They add no runtime lease and need no Rails, Active Record, database, capture,
parser, Map or server. Both human demos and Leah's browser remain untouched.

Reuse `tools/check_install.rb`'s existing fresh installed Core harness. Stage
only this fixture directory outside the checkout and retain its exact hashes.
Run its producer once with a new temporary **public fixture** directory, then
its consumer in a fresh process with the retained producer JSON as its sole
argument. Both use only the installed Core. Set
`THISTLE_FIXTURE_INSTALLED_ROOT` explicitly to the harness's actual installed
package prefix (for its consumer bundle, `Bundler.bundle_path`); each script
verifies the loaded Core gem is underneath that prefix. Keep any private
receipt/log paths and caller-supplied roots out of public delivery prose.

`produce.rb` publishes small, literal public schema-1 fixtures through
`Thistle::Store#publish`, not capture. It creates saved A, publishes distinct B,
changes live source to B, removes one file and substitutes a symlink for another.
No fixture source is required/evaluated. Its receipt identifies both generations,
explicit operator roots, one saved fact ID and a finite list of protected file
digests (CURRENT, each generation's manifest/facts and known source blobs).

`expected_cards.json` supplies independent exact saved content/digest/byte cards.
`consume.rb` opens pinned A and checks nil-root, matching, changed, empty,
missing, symlink and byte/unsafe-root refusals. It requires ordinary Source to
remain A, Check to remain integrity verified/freshness not_checked, CURRENT B to
remain distinct and every protected file to retain its digest. The Rust tests
cover deterministic permission/I/O/interruption/race injections; do not make a
filesystem chmod test pretend to cover privileged unreadability.

Root must integrate the new installed document into the Core gemspec and exact
package-doc assertions, and stage/run these two scripts through the existing
installed harness. That shared packaging work is deliberately outside this
writer's paths. Source checks, installed artifact checks, served presentation
and applicable Leah acceptance are different evidence. Preserve failed or
inconclusive attempts and exact artifact/support identities. All17 UNQUALIFIED.

The later Map freshness action/result still requires its own admitted phase;
see `served_protocol.md`. Core's Reader contract does not become a prerequisite
for the separate Map LOS153 change, which uses the existing API.
