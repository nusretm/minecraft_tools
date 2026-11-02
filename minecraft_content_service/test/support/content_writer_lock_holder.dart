import 'dart:convert';
import 'dart:io';

// Run by the test suite in an independent Dart process. Does not modify
// any installation manifest or artifact.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) throw ArgumentError('Expected a lock file path.');
  final handle = await File(arguments.single).open(mode: FileMode.append);
  stdout.writeln('attempting');
  await stdout.flush();
  await handle.lock(FileLock.blockingExclusive);
  try {
    stdout.writeln('locked');
    await stdout.flush();
    await stdin.transform(utf8.decoder).transform(const LineSplitter()).first;
  } finally {
    try {
      handle.unlockSync();
    } finally {
      handle.closeSync();
    }
  }
}
