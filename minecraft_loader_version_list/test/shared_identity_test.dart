import 'package:minecraft_loader_version_list/minecraft_loader_version_list.dart' as loader;
import 'package:minecraft_models/minecraft_models.dart' as shared;
import 'package:test/test.dart';

void main() {
  test('Public API re-exports the shared model identities', () {
    const loader.MtnLauncherGameLoaderMinecraftVersion game = (
      mcVersion: '1.21.1',
      versionId: '1.21.1',
      type: loader.MtnLauncherGameVersionType.release,
    );
    const loader.MtnLauncherGameLoaderVersion version = loader.MtnLauncherGameLoaderVersion(
      mcVersion: '1.21.1',
      version: 'loader-build',
      url: 'https://example.com/loader-build',
      type: loader.MtnLauncherGameVersionType.release,
      channel: loader.MtnLauncherGameLoaderChannel.stable,
      sha1: 'A19f49d4b31af176d9699c7e8fdc4ea2d551aa09',
    );

    const shared.MtnLauncherGameLoaderMinecraftVersion sharedGame = game;
    const shared.MtnLauncherGameLoaderVersion sharedVersion = version;
    const shared.MtnLauncherGameVersionType sharedType = loader.MtnLauncherGameVersionType.release;
    const shared.MtnLauncherGameLoaderChannel sharedChannel = loader.MtnLauncherGameLoaderChannel.stable;

    expect(sharedGame, game);
    expect(sharedVersion, same(version));
    expect(sharedVersion.sha1, 'A19f49d4b31af176d9699c7e8fdc4ea2d551aa09');
    expect(sharedVersion.toJson()['sha1'], version.sha1);
    expect(sharedType, shared.MtnLauncherGameVersionType.release);
    expect(sharedChannel, shared.MtnLauncherGameLoaderChannel.stable);
  });
}
