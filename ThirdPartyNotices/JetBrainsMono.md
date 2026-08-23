# JetBrains Mono font notices

This notice covers the unmodified JetBrains Mono font files distributed for
Egakium's app-owned macOS and iOS interface and Markdown text. LaTeX formula
layout remains owned by the separately pinned iosMath dependency and its
audited math-font bundle.

## Upstream identity and scope

- Upstream: <https://github.com/JetBrains/JetBrainsMono>
- Version/tag: `v2.304`
- Commit: `cd5227bd1f61dff3bbd6c814ceaf7ffd95e947d9`
- Official release asset:
  `JetBrainsMono-2.304.zip` (5,622,857 bytes)
- Official release asset SHA-256:
  `6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf`
- Local reuse mode: unmodified font assets bundled as a dependency
- License: SIL Open Font License 1.1
- Copyright notice: Copyright 2020 The JetBrains Mono Project Authors
  (<https://github.com/JetBrains/JetBrainsMono>)

Egakium copies ten static TTF faces from the official release. It does not
copy the NL family, variable fonts, webfonts, source files, build scripts, or
JetBrains product/IDE assets. The fonts retain their upstream filenames,
family names, PostScript names, metadata, and bytes.

The app loads the exact bundled `CGFont` objects directly and creates Core
Text fonts from them. It does not depend on a user-installed font, does not
register a persistent system font, and does not silently substitute a second
Latin family. JetBrains Mono contains no Chinese glyph set, so Core Text's
unchanged Apple cascade continues to resolve Chinese text through the
appropriate PingFang family. Other missing scripts and symbols remain subject
to the platform fallback cascade.

## Distributed font inventory

| File | SHA-256 |
| --- | --- |
| `JetBrainsMono-Light.ttf` | `60c18d7dd58d81b3bbd12e8ce32744a8771bfe2b5280574082b0eaed46c60d24` |
| `JetBrainsMono-LightItalic.ttf` | `18ffadb91fa711b45feae027ddfd561e7f97ace805ec4baf9905046cf450befb` |
| `JetBrainsMono-Regular.ttf` | `a0bf60ef0f83c5ed4d7a75d45838548b1f6873372dfac88f71804491898d138f` |
| `JetBrainsMono-Italic.ttf` | `9d0a1f7a708e6af183f1193b7e81d40da294f5c67682c085d8401c60aac8ded4` |
| `JetBrainsMono-Medium.ttf` | `31c92d01a8a08528b718a43addf0ad3df0af2ca4b7b3290a452f70f358e14d3d` |
| `JetBrainsMono-MediumItalic.ttf` | `4477fda6bd472ef96b11bc1083370f7fc3ff427bdc807e682ced5819e3dee9df` |
| `JetBrainsMono-SemiBold.ttf` | `1b3bfa1ed5665a4ce3f9feb68d2d4e40e70bf8b4b7d9a3edd418f321b4e166a0` |
| `JetBrainsMono-SemiBoldItalic.ttf` | `3b3000507a7285872395ddbb4e53a28f07910dbf494fb0d5e1421dd60b5d8436` |
| `JetBrainsMono-Bold.ttf` | `5590990c82e097397517f275f430af4546e1c45cff408bde4255dad142479dcb` |
| `JetBrainsMono-BoldItalic.ttf` | `4039d5ce0ed225bf9c8b2c8c6436290ae2f356b7e90d70fa666227238324aa3b` |

The exact upstream OFL text is preserved at
`ThirdPartyNotices/Licenses/JetBrainsMono-2.304-OFL-1.1.txt`; the official
release author list is preserved at
`ThirdPartyNotices/Licenses/JetBrainsMono-2.304-AUTHORS.txt`. Both files are
copied into the macOS and iOS App resource inventory together with this
notice through the existing `ThirdPartyNotices` resource folder.

## SIL Open Font License compliance

The font files are distributed unmodified and are not sold by themselves.
Every distributed App copy includes the upstream copyright notice and the
complete OFL 1.1 text. Egakium does not use the JetBrains or JetBrains Mono
names to imply endorsement, and it does not create a modified font that would
need a different primary font name.
