# Finished PDF manuals

This folder contains only finished PDFs to share, print, or email.

| File | Audience |
|------|----------|
| [myRekod_User_Manual.pdf](myRekod_User_Manual.pdf) | Employees & administrators |
| [myRekod_Developer_Handover.pdf](myRekod_Developer_Handover.pdf) | New developers |

Do not edit PDF files directly.

## Update a manual

1. Edit the Markdown chapters in `../user/` or `../developer/`.
2. From the project root, rebuild both PDFs:

```bash
node "docs (UserManual & Guide)/scripts/build-pdf-manuals.mjs"
```

The build script creates both PDFs from the Markdown chapters. It does not keep a duplicated `_build_*.md` copy.
