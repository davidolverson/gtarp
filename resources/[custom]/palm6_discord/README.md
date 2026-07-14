# palm6_discord — signature-system Discord feed announcer

One server-side resource owns every **player-facing** Discord post, so rate
limiting, retry, and formatting live in exactly one place. Producers push
through a soft-dependency guard — this resource being absent, stopped, or
unconfigured never breaks gameplay.

## Feeds

| Feed     | Producer / moment                                             | Convar                 |
|----------|---------------------------------------------------------------|------------------------|
| `drops`  | palm6_flashdrop — drop armed (no location, hype only)         | `palm6:discord_drops`  |
| `market` | palm6_pumpcoin — new listing, rug pull, identity reveal       | `palm6:discord_market` |
| `live`   | palm6_clout — streamer goes live (mirrors in-city announce)   | `palm6:discord_live`   |
| `police` | palm6_evidence — new case file opened (police channel)        | `palm6:discord_police` |
| `heat`   | palm6_counterfeit — district heat bulletin (Weazel News tone) | `palm6:discord_heat`   |

Set each convar to a Discord webhook URL in `custom.cfg`. Unset = feed off.
The boot banner names live and off feeds.

## Information discipline

- Posts never say anything the city doesn't already know: flashdrop posts
  omit the location (the in-game hint system owns reveals), pumpcoin posts
  omit creator identity until the in-game reveal makes it public record,
  heat bulletins carry a district label but no coordinates and no heat
  number.
- **This is not the ops plumbing.** `palm6_staff`'s audit webhook
  (`palm6:staff_webhook`) and `palm6_perf`'s hitch webhook
  (`palm6:perf_webhook`) stay separate — staff-only data must not share a
  pipeline with public channels.
- Server-side only, deliberately no net event inbound: a modified client
  can never post to the community Discord.

## Exports

- `Announce(feed, { title, description, fields?, color? }) -> boolean` —
  queue an embed. Returns false (and does nothing) for unknown feeds, off
  feeds, a flooding feed, or an unencodable payload. Strings are truncated
  to Discord's embed limits.
- `GetStats() -> { queued, dropped, liveFeeds }`

## Delivery behaviour

One FIFO queue drained every `Config.SendEveryMs` (default 2.5s — safely
under Discord's ~30/min/webhook even if all feeds share one webhook).
Per-feed clamp of `Config.PerFeedPerMinute` (default 10) so one buggy
producer can't starve the others. 429 responses retry once honouring
Retry-After; other failures drop the message with a console line. Queue cap
`Config.MaxQueue` (default 40), oldest dropped first.

## Adding a producer

```lua
local function discordAnnounce(payload)
    if GetResourceState('palm6_discord') ~= 'started' then return end
    pcall(function() exports.palm6_discord:Announce('<feed>', payload) end)
end
```

Add the feed to `shared/config.lua` if it's a new channel. Never announce
from a client-triggered path without server-side validation upstream.
