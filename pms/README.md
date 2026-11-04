# pms

No PMS release yet. The first `pms-<version>` tag writes `pms/stable.json`,
`pms/stable.json.sig` and `pms/notes/<version>.md` here (through the PMS release workflow, after
the GitHub Release and its assets exist).

`stable.json` shape (example):

```json
{
  "component": "pms",
  "version": "2026.11.0",
  "tag": "pms-2026.11.0",
  "builtAt": "2026-11-04T12:00:00Z",
  "minimumFrom": "2026.11.0",
  "image": { "name": "ghcr.io/hotel-assistant/pms", "tag": "2026.11.0", "digest": "sha256:…" },
  "files": {
    "vercel": { "name": "pms-vercel-2026.11.0.tgz", "url": "https://github.com/Hotel-Assistant/releases/releases/download/pms-2026.11.0/pms-vercel-2026.11.0.tgz", "sha256": "…", "bytes": 123 }
  },
  "notes": "https://hotel-assistant.github.io/releases/pms/notes/2026.11.0.md"
}
```

Unknown keys are ignored by every consumer.
