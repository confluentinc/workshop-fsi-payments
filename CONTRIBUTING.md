# Contributing

## Author of record

Kyle Klein (kklein@confluent.io)

## Conventions

- Match existing Markdown style: `##`/`###` headers, bullet-first, tables for matrices, GitHub callouts (`> [!NOTE]`, `> [!WARNING]`, `> [!TIP]`).
- Keep the three RiverPulse business questions consistent across README, labs, deck, and facilitator script.
- Phase 1 scope is locked in [AGENTS.md](AGENTS.md) — do not silently expand into Phase 2.
- Prefer reusable, customizable workshop content (e.g. Elevate 2026 DSP).

## Terraform

- Cloud path: work in `terraform/aws-demo` via Docker Compose.
- CP/ROSA path: host Terraform in `terraform/cp-rosa/stage1-rosa` then `stage2-cfk` (two-stage apply).
- Never commit `terraform.tfvars`, state, SSH keys, or kubeconfig copies.
- When changing Cloud modules, update LAB2 “What Terraform Creates” and the Phase 1 runbook.
- When changing cp-rosa, keep `labs/cp-rosa/` and `context/cp_rosa_demo_talk_track.md` in sync.

## Pull requests

- Use conventional commits where practical (`feat:`, `fix:`, `docs:`).
- Describe why the change helps the demo narrative or reliability.
