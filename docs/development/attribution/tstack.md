# Selected tstack skill adaptations

The existing Thistle Build, Review and Hand off skills adapt selected procedures
from [t3dotgg/tstack at the reviewed commit](https://github.com/t3dotgg/tstack/tree/1085050f3baed1ac724caa4a8166145fb2ac88af).
The pinned files and license were read directly; their raw bytes were hashed and
the Git blob identities independently matched against the pinned tree.

| Source at the pinned commit | Git blob | SHA-256 of raw bytes |
| --- | --- | --- |
| [skills/babysit-pr/SKILL.md](https://github.com/t3dotgg/tstack/blob/1085050f3baed1ac724caa4a8166145fb2ac88af/skills/babysit-pr/SKILL.md) | `7afd153f2b918b8768c895fe9dff0390da8d7d29` | `fbe43ba3ab76a466a88ef8b46dca1b41fb8101347d24a396903849865173a6ac` |
| [skills/sol-loop/SKILL.md](https://github.com/t3dotgg/tstack/blob/1085050f3baed1ac724caa4a8166145fb2ac88af/skills/sol-loop/SKILL.md) | `6b6892db436c5dfc3443f06569aaca89d7d1f902` | `1db1eb4c4a156ee666070e9a12623d520cd1bd9b19c3fc21003fe5a440ba0b10` |
| [skills/takeover/SKILL.md](https://github.com/t3dotgg/tstack/blob/1085050f3baed1ac724caa4a8166145fb2ac88af/skills/takeover/SKILL.md) | `17805d62d097569feb33917afcacdb7207828672` | `9f00a7c67bf82603af2e80f56e9ce63f1516a1b4339365b79cf786d9d9055465` |
| [skills/modernize/SKILL.md](https://github.com/t3dotgg/tstack/blob/1085050f3baed1ac724caa4a8166145fb2ac88af/skills/modernize/SKILL.md) | `3ace16d4629f936a83a2ec359ac5dc7b0bf318c0` | `6172d774c46f535367086da90db1b0aaaaac969ed05ff040444f9afa9a6b1552` |
| [LICENSE](https://github.com/t3dotgg/tstack/blob/1085050f3baed1ac724caa4a8166145fb2ac88af/LICENSE) | `eccbd9f1c676d8cbb191a5064c48118492b74125` | `8095f9a9f97d074131f6a2ce09b952d12c18b36f09f4e5df0517c4e64e82c851` |

## Scope and fit

- `babysit-pr`: one owning thread, existing findings before native watch, event
  delivery followed by turn end, quiet no-action handling and watch retirement.
- `sol-loop`: one full independent initial review, stable finding dispositions,
  later review of changed code/open findings, and a finite review budget.
- `takeover` and `modernize`: current-state verification, contributor credit,
  conceptual reconciliation with newer main, and range-diff after an authorized
  rebase.

Thistle retains its own severity, performance, security, lifecycle, evidence,
signing and authority rules. Three review rounds is a ceiling; provider choice
uses installed capabilities and existing access/egress authority. Older-head
findings may remain applicable; rare paths and repeated small costs are assessed
on consequences. Applicable unchanged evidence need not be rerun personally.
Observed remote HEAD and explicit force-push authority are both prerequisites.
No upstream merge, queue, automerge, fetch, setup or force-push permission is
imported. Required post-merge checks retain a named owner without blocking
disjoint source work merely because monitoring continues.

Native T3 watch was selected over importing the bundled `pr-wait` script because
Thistle already uses T3 event delivery. No watcher/script, scheduler, provider
installation or runtime dependency is copied or executed. The ongoing cost is
maintaining these small procedures against the existing gates and installed tool
contract. They suppress duplicate handling, not notifications emitted by T3;
missing native access remains an explicit handoff gap. Reconsider tool fit if
that event contract or the repository workflow changes, within a separate scope.
The skills, this note and pending fragments remain repository documentation,
outside the explicit Core and Map gem payload manifests.

## MIT notice

The following full upstream notice applies to the copied/adapted material above.

```text
MIT License

Copyright (c) 2026 Theo Browne

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
