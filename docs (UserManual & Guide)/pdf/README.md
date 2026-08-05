# PDF manuals

Ready-to-share PDF files for handover.

| File | Audience |
|------|----------|
| [myRekod_User_Manual.pdf](myRekod_User_Manual.pdf) | Employees & administrators |
| [myRekod_Developer_Handover.pdf](myRekod_Developer_Handover.pdf) | New developers |

## Source markdown (for regenerating)

- `_build_user_manual.md`
- `_build_developer_handover.md`

Regenerate (requires Node.js):

```bash
npx --yes md-to-pdf docs/pdf/_build_user_manual.md
npx --yes md-to-pdf docs/pdf/_build_developer_handover.md
```

Then rename the output PDFs if needed.

Markdown sources for editing live under `docs/user/` and `docs/developer/`.
