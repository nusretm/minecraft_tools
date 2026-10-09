import 'package:test/test.dart';
import 'package:minecraft_loader_version_list/minecraft_loader_version_list.dart';
import '../example/loader_versions.dart' as example;

void main() {
  test('Forge Maven preserves the exact full artifact version', () {
    const xml = '<versions><version>1.8.9-11.15.1.2318-1.8.9</version><version>1.20.1-47.3.0</version></versions>';
    expect(example.readMavenVersions(xml), ['1.8.9-11.15.1.2318-1.8.9', '1.20.1-47.3.0']);
  });

  test('Fabric uses only affirmative official stable metadata for stable', () {
    expect(example.fabricLoaderChannel({'version': '0.16.10', 'stable': true}), MtnLauncherGameLoaderChannel.stable);
    expect(example.fabricLoaderChannel({'version': '0.16.10', 'stable': false}), MtnLauncherGameLoaderChannel.unknown);
    expect(example.fabricLoaderChannel({'version': '0.17.0-beta.1', 'stable': false}), MtnLauncherGameLoaderChannel.beta);
  });

  test('Loader channels require explicit prerelease markers', () {
    expect(example.loaderChannelFromVersion('1.20.1-47.3.0'), MtnLauncherGameLoaderChannel.unknown);
    expect(example.loaderChannelFromVersion('21.1.211'), MtnLauncherGameLoaderChannel.unknown);
    expect(example.loaderChannelFromVersion('0.28.0-rc.1'), MtnLauncherGameLoaderChannel.unknown);
    expect(example.loaderChannelFromVersion('0.28.0-beta.1'), MtnLauncherGameLoaderChannel.beta);
    expect(example.loaderChannelFromVersion('21.4.0-alpha.3'), MtnLauncherGameLoaderChannel.alpha);
    expect(example.loaderChannelFromVersion('21.4.0-experimental.2'), MtnLauncherGameLoaderChannel.experimental);
  });

  test('Minecraft type is independent of loader build stability', () {
    expect(example.minecraftTypeFromId('1.21.1', manifestType: 'release'), MtnLauncherGameVersionType.release);
    expect(example.minecraftTypeFromId('1.21.1-pre1', manifestType: 'snapshot'), MtnLauncherGameVersionType.preRelease);
    expect(example.minecraftTypeFromId('1.21.1-rc1', manifestType: 'snapshot'), MtnLauncherGameVersionType.releaseCandidate);
    expect(example.minecraftTypeFromId('24w33a', manifestType: 'snapshot'), MtnLauncherGameVersionType.snapshot);
    expect(example.minecraftTypeFromId('b1.7.3', manifestType: 'old_beta'), MtnLauncherGameVersionType.beta);
    expect(example.minecraftTypeFromId('a1.2.6', manifestType: 'old_alpha'), MtnLauncherGameVersionType.alpha);
    expect(example.minecraftTypeFromId('26.1-snapshot-1'), MtnLauncherGameVersionType.snapshot);
    expect(example.minecraftTypeFromId('1.14 Pre-Release 5'), MtnLauncherGameVersionType.preRelease);
    expect(example.minecraftTypeFromId('unexpected-id'), MtnLauncherGameVersionType.unknown);
  });

  test('Preserve exact upstream ID while grouping explicit previews', () {
    expect(example.minecraftVersionGroupFromId('1.21.1-pre1'), '1.21.1');
    expect(example.minecraftVersionGroupFromId('1.21.1-rc1'), '1.21.1');
    expect(example.minecraftVersionGroupFromId('24w33a'), '24w33a');
    expect(example.minecraftVersionGroupFromId('26.1-snapshot-1'), '26.1');
  });

  test('NeoForge version inference covers old and modern notation', () {
    expect(example.minecraftVersionFromNeoForge('20.2.59'), '1.20.2');
    expect(example.minecraftVersionFromNeoForge('21.1.211'), '1.21.1');
    expect(example.minecraftVersionFromNeoForge('21.0.167'), '1.21');
    expect(example.minecraftVersionFromNeoForge('26.1.0.10-beta'), '26.1');
    expect(example.minecraftVersionFromNeoForge('26.1.1.5'), '26.1.1');
    expect(example.minecraftVersionFromNeoForge('26.1.0.0-alpha.2+snapshot-1'), '26.1-snapshot-1');
  });
}
