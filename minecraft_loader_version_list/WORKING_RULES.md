# Minecraft Loader Version List Working Rules

`../docs/WORKING_RULES.md` remains authoritative. These package-specific rules narrow that repository-wide contract:

- Keep `MtnLauncherGameLoaderVersionList` provider-independent.
- `minecraft_models` is the single authority for shared loader/version models and enums; do not duplicate them here.
- Minecraft version type and loader publication channel are separate concepts.
- Preserve exact upstream version IDs and provider-owned URLs without normalization or reconstruction.
- Never treat `unknown` loader channel as `stable`.
- Do not confuse catalog/build cache or network failures with an unsupported Minecraft version.
- Natural ordering is best-effort and does not guarantee upstream publication chronology.
- Keep provider parsing and provider wire-format knowledge inside callbacks or `example/`.
- Do not run `dart format` for this pure-Dart package.
- Changes to sibling packages are outside this package's scope.
- Do not merge PR #57 without separate user approval.
