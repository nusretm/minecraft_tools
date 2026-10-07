# Minecraft Tools — Minecraft Content CLI Example Handoff

Date: 2026-10-07

## Status

```text
Repository: nusretm/minecraft_tools
Package: minecraft_content_service/
Branch: feature/minecraft-content-cli-example
Implementation: COMPLETE
Validation: COMPLETE
Live Modrinth smoke: PASSED
Merge: NOT REQUESTED
Validated HEAD:
ab1428bd134e4444a4f4c297c1001a5de93ccf78
```

Baseline:

```text
main
d3e902633f34e1d56ccf70925b3828d2c6879851
Merge pull request #30 from nusretm/feature/minecraft-content-provider-modrinth-foundation
```

## Goal

Provide a small real CLI proving that the generic content-service API and the concrete Modrinth provider work together end-to-end.

## CLI

File:

```text
minecraft_content_service/example/mc_content.dart
```

Supported arguments:

- `--provider`
- `--content`
- `--filter`
- `--mc-version`
- `--loader`

Currently supported provider:

```text
modrinth
```

Supported generic content values include mod, modpack, resourcepack, shaderpack and datapack.

Supported loader parsing maps common CLI names into the existing generic loader enum.

## Validated live command

```powershell
dart run example/mc_content.dart --provider modrinth --content mod --filter "Skyblocker" --mc-version 26.1.2 --loader fabric
```

Observed live result count:

```text
3 shown / 3 total
```

Observed results included:

```text
Skyblocker • Hypixel Skyblock
Bazaar Utils ✦ Hypixel Skyblock
CasualSkyblockZAddons [CSZA]
```

The output also successfully exposed normalized content type, provider ID, author, summary, categories, update timestamp and icon URL.

## Architecture exercised

```text
CLI options
→ MtnMinecraftContentSearchRequest
→ MtnMinecraftContentService.search()
→ registered MtnMinecraftContentProviderModrinth
→ Modrinth facets/query
→ normalized MtnMinecraftContentSearchResult
→ console output
```

This confirms that provider selection remains explicit and that provider-specific search behavior stays behind the generic service contract.

## Validation

```text
dart analyze
No issues found!

dart test
00:00 +17: All tests passed!

live Modrinth CLI smoke
PASS
```

The live command specifically validated:

- provider selection = Modrinth
- content type filter = mod
- text filter = Skyblocker
- Minecraft version filter = 26.1.2
- loader filter = Fabric
- real remote search response mapping
- normalized CLI presentation

## Deliberately not included

- CurseForge CLI support
- interactive prompts
- result selection/details drill-down
- project version listing from the CLI
- downloads/materialization
- dependency solving

Future providers can extend the same example provider-selection branch after their concrete provider implementations exist.

Merge of this branch requires separate explicit approval.
