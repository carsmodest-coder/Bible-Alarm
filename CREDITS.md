# Credits

Sources and licenses for everything bundled in the app that we did not create ourselves.

## Bible text

All three translations are in the public domain. The text files come from the
[open-bibles](https://github.com/seven1m/open-bibles) collection, which lists each of them as
"Public Domain". They are converted to the app's compact JSON by `Tools/build_bibles.py`
(notes, headings and Psalm titles are removed; the verse text is not changed).

| File in the app | Translation | Source file | License |
|---|---|---|---|
| `kjv.json` | King James Version (1769 text) | `eng-kjv.osis.xml` | Public domain |
| `web.json` | World English Bible | `eng-web.usfx.xml` | Public domain |
| `cuv.json` | 和合本 Chinese Union Version (1919), Traditional Chinese | `chi-cuv.usfx.xml` | Public domain |

Notes:

- "World English Bible" is a trademark of eBible.org. The name may be used for the unaltered text, which is what the app bundles.
- In the United Kingdom the King James Version is covered by Crown letters patent. Everywhere else it is public domain. Ryder should decide whether that matters for a UK App Store listing.
- `verse_sets.json` (the curated list of morning verses and themed sets) and the reading plans were written for this app. They contain references only, no text.

## Sounds

- `dawn.wav`, `chimes.wav`, `harp.wav`, `still_waters.wav`: generated for this project by `Tools/make_sounds.py`
  from sine waves. No samples or recordings from anywhere else. Original to this project.
- Sounds a user imports or records stay on their device and are not part of the app.

## App icon

- Placeholder icon generated for this project. To be replaced by Ryder's design.

## Code

- No third-party libraries or SDKs. Apple frameworks only.
