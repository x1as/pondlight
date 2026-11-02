# Steam setup — what is done and what remains

## Status (honest)
| Feature | State |
|---|---|
| Windows x64 release build | **Done** — `build/windows/Pondlight.exe`, single file, verified to launch and play |
| Linux x86_64 build | Exported (`build/linux/Pondlight.x86_64`), **not run-tested** (no Linux machine here) |
| Platform abstraction | **Done** — all achievement/stat calls go through `Platform` (`scripts/autoload/platform_service.gd`) |
| Local achievements | **Done** — 25 data-driven trophies + the platinum grand trophy, stored in the save, shown in the Trophy Cabinet |
| Steam achievements | **Not active.** No Steamworks SDK, GodotSteam build or App ID were available. |
| Steam Cloud | **Not configured** (see below; the save layout is ready for it) |
| Steam overlay / Steam Input | Not integrated; the game uses standard XInput/SDL gamepad input, which Steam Input can remap. |

No App ID has been invented and no third-party extension was installed.

## Demo
The separate demo build was removed in v0.4 (owner decision): there is one build. Put the real store URL in `pondlight/data/store.json → store_url` once the page exists.

## Steps to finish
1. **Steamworks partner account** → create the app → note the real **App ID**.
2. **GodotSteam for Godot 4.7.x**: use the official GodotSteam GDExtension (or a pre-compiled editor/templates build) whose release notes list Godot 4.7 support. Verify compatibility before installing; do not mix versions.
3. During development put `steam_appid.txt` (containing your App ID) next to the executable. **Do not ship it.**
4. Steam backend: `Platform` already detects a `Steam` singleton and calls `steamInitEx`, `run_callbacks`, `setAchievement` + `storeStats`.
   With the GDExtension version the API is reached the same way (`Engine.has_singleton("Steam")`). Review `platform_service.gd` against the GodotSteam version you install.
5. **Achievements**: in Steamworks → Stats & Achievements create the API names exactly as the `id` fields in `pondlight/data/achievements.json`
   (`FIRST_CATCH`, `CATCH_100`, `CATCH_500`, `FIRST_RARE`, `FIRST_EPIC`, `FIRST_LEGENDARY`, `PRISMATIC`, `PERFECT_50`, `COMBO_8`,
   `WILLOW_COMPLETE`, `FROST_COMPLETE`, `DELTA_COMPLETE`, `TRENCH_COMPLETE`, `UNLOCK_TRENCH`, `MASTER_10`, `MASTER_20`, `FULL_GEAR`,
   `TALENT_50`, `EARN_250K`, `STREAK_10`, `GOLDEN_SPOT`, `TREASURE_5`, `HIGH_TIDE`, `CATCH_KRAKEN`, `CATCH_MEGALODON`, `PONDLIGHT_MASTER`). Icons: export from `assets/art/ui/icons` at 4–8×.
   Existing players get their local achievements re-sent automatically because `Achievements.check_all()` runs after every catch (add a one-time resync call on Steam init if desired).
6. **Steam Cloud (Auto-Cloud)**: root `WinAppDataRoaming`, subdirectory `Godot/app_userdata/Pondlight`, patterns `save.json`, `save.bak.json`, `settings.cfg`.
   (If you enable `application/config/use_custom_user_dir`, update the path.)
7. **Depots**: upload the contents of `build/windows/` (just `Pondlight.exe`). Launch option: `Pondlight.exe`. Optional Linux depot with `build/linux/`.
8. Store assets: capsule art can be composed from `assets/art/world/*/_preview.png` (scaled ×4 nearest) + `assets/art/ui/logo.png`.
9. Rebuild with `build_release.ps1` and test through the Steam client (overlay Shift+Tab, achievements, cloud) before release.
