# Deck

The slides live as a Claude Slides artifact (Upbound Design System):
<https://claude.ai/artifact/D1jpS3rpmEaPnoxCr9WsGW>. Export a PDF from its
Share menu for the sched upload, and a PPTX if you want to edit offline. Every
slide has speaker notes.

## Run of show (80 min)

| Time | Slides | Segment |
|---|---|---|
| 0:00 | cover, start, agenda | Welcome. Everyone runs `./scripts/setup.sh` (or `--check` if they did it beforehand). Pair up anyone it fails for. |
| 0:05 | why-functions … before-after | Why functions, the ecosystem, management policies, the design. 10 min: keep it moving. |
| 0:15 | lab1 | Lab 1, 8 min |
| 0:23 | lab2 | Lab 2, 15 min |
| 0:38 | lab3 | Lab 3, 10 min |
| 0:48 | lab4 | Lab 4, 8 min. Elastic: if the room is behind, demo it on the projector instead. |
| 0:56 | lab5 | Lab 5, 12 min: the Operation, then draft PRs |
| 1:08 | lab6 | Lab 6, 8 min: `./e2e/run.sh` on the cluster `setup.sh --e2e` made, the dropped-capability failure, then `gh pr ready`. Elastic: if the room is behind, run it on the projector from your warm cluster, and people finish at home. |
| 1:16 | pr-checklist … thanks | 4 min: what maintainers check, the AI policy, then the journey to maintainer, curated issues, feedback, group photo. Skim debug-toolkit and polyglot: the lab pages have both. |

## Before Nov 11

- [ ] Post the setup instructions (PREREQUISITES.md) on sched and in Crossplane Slack a week ahead. Ask people with Docker to run `./scripts/setup.sh --e2e`.
- [x] QR code on the `start` slide (hub repo; decoded and checked on 2026-11-03)
- [ ] QR code on the `thanks` slide (session feedback): needs the sched link
- [x] Crossplane logo on the cover (white horizontal logo from cncf/artwork)
- [ ] Record Lab 6 on the presenter laptop as a Wi-Fi fallback
- [ ] Names of the table helpers for the cover's speaker notes
