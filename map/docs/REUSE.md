# Woods Map reuse record

Owner authorization was explicit in the Thistle design discussion. Upstream project: [lost-in-the/woods-map](https://github.com/lost-in-the/woods-map), pinned revision `29e7f6ac60bdeb8eee50138c2c87bd7ae21442a9`. Upstream MIT copyright/permission is reproduced in [LICENSE.woods-map.txt](../LICENSE.woods-map.txt).

| Upstream path | Upstream Git blob | Thistle use |
|---|---|---|
| `app/assets/stylesheets/woods_map/tokens.css` | `28876d6fb3455381bb8c961e9e25654f77bb8451` | `assets/woods-map-tokens.css`, complete stylesheet, unchanged bytes. The CodePigeon palette, typographic roles, token classes and components remain visible. |
| `lib/woods_map/highlighter.rb` | `3768fc52d9932afd9a199c03d232b4a3a12a9a93` | `lib/thistle/map/highlighter.rb`, adapted lexer/class mapping, lossless token checks and per-line rendering. Namespace changed. Old typed-target link renderer removed because Thistle has not verified those spans. Unknown file extensions stay plain text. Lexer failure returns escaped plain text. |
| `app/views/woods_map/units/_code_view.html.erb` | `add843e1a18d88c7109262c30e19b7ed8ac79f92` | Source view structure adapted into `View#source`: one accessible scroll region, source/line-number lanes and captured-source explanation. Old schema/concern composition, heat, history and caller lanes are not represented as available. |
| `app/views/woods_map/components/_facts.html.erb` | `e6fb42c404676ec0d26371758dd81285dd8176e0` | Fact-tile markup adapted into `View#fact_tiles`, with explicit escaping for plain ERB/Rack presentation. |
| `LICENSE.txt` | `0d3ca26b4a4046dcf21c7a054dc6597be6255c9d` | Preserved as `LICENSE.woods-map.txt`. |

No Woods extraction, reader, storage, MCP, origin-policy or executable code was reused. The new App gate and reader adapter are independently written. A syntax highlighter is presentation: its tokens do not create new program-analysis facts.

The unchanged stylesheet deliberately includes components beyond this slice. Removing unused rules is a later measured asset-size optimization; the original stylesheet is the visual baseline. There are no remotely loaded fonts or scripts.

This is a real source-to-UI integration path using reused presentation code. It does not qualify the complete upstream Map feature set or claim the current design's usability is proven.
