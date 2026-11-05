# v1.0 acceptance checklist

This is a release gate, not a claim of implementation. README claims and static code inspection do not substitute for live-client evidence. Check a box only after its behavior is verified; record test date/client and evidence in this file.

- [ ] Live-test server C_DamageMeter availability and protected values in combat and after combat
- [ ] Verify current/overall, player identity, group ranking and top-N behavior
- [ ] Verify default silence and opt-in announcements, no duplicate reports
- [ ] Exercise solo/party/raid and disconnect/reload behavior
- [ ] Verify release packaging and settings migration

## Evidence

- Code review: 2026-11-05 reviewed Core.lua combat lifecycle; guarded delayed post-fight reporting against combat restart, meter reset, and world transitions (commit 0c42da4). This is a code-level safeguard, not live-client verification.
- Automated/static tests: pending; no WoW runtime available in this run. Verify delayed callback cancellation with rapid combat restart and meter reset in client.
- Live WoW: Forever client verification: pending
- Release ZIP and WoWUp installation: pending

## Status

Pre-1.0. Features described in README may be implemented but are not accepted as verified here until tested. Avoid declaring v1.0 solely on version metadata.

## Phase 1 implementation — encounter report lifecycle (2026-11-05)

- [x] Clear the previous finished-fight summary when a new combat starts, and refuse `/fdps report` while combat is active or the delayed end-of-fight snapshot is pending (`Core.lua`, commit `a543e86`). Prevents manually broadcasting a stale previous encounter as the current one; default chat silence unchanged.
- [ ] Exercise combat restart, manual report before the delayed snapshot, combat exit, and meter reset in the live client. Code inspected; no Lua harness or live-client evidence for this change.
