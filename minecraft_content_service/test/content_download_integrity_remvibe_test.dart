import 'dart:io';

import 'package:minecraft_content_service/minecraft_content_service_remvibe.dart';
import 'package:test/test.dart';

void main() {
  group('MtnMinecraftContentDownloadIntegrityRemVibe', () {
    test('returns null when file metadata has no verifiable size or supported checksum', () {
      final noMetadata = _file(size: null);
      final unsupportedOnly = _file(
        size: null,
        hashes: <MtnMinecraftContentFileHash>[
          MtnMinecraftContentFileHash(
            algorithm: 'curseforge:99',
            value: 'provider-specific-value',
          ),
        ],
      );

      expect(
        MtnMinecraftContentDownloadIntegrityRemVibe.fromFile(noMetadata),
        isNull,
      );
      expect(
        MtnMinecraftContentDownloadIntegrityRemVibe.fromFile(unsupportedOnly),
        isNull,
      );
    });

    test('validates expected size without requiring a checksum', () async {
      final integrity = MtnMinecraftContentDownloadIntegrityRemVibe.fromFile(
        _file(size: 5),
      )!;
      final directory = await Directory.systemTemp.createTemp();
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}size.bin');
      await file.writeAsBytes(<int>[1, 2, 3, 4, 5]);

      await expectLater(integrity.validate(file), completes);

      await file.writeAsBytes(<int>[1, 2, 3, 4]);
      await expectLater(
        integrity.validate(file),
        throwsA(
          isA<MtnMinecraftContentDownloadIntegrityException>().having(
            (error) => error.message,
            'message',
            contains('size mismatch'),
          ),
        ),
      );
    });

    test('canonicalizes supported aliases and validates all supported checksums in one policy', () async {
      final integrity = MtnMinecraftContentDownloadIntegrityRemVibe.fromFile(
        _file(
          size: 5,
          hashes: <MtnMinecraftContentFileHash>[
            MtnMinecraftContentFileHash(
              algorithm: 'md5',
              value: '5D41402ABC4B2A76B9719D911017C592',
            ),
            MtnMinecraftContentFileHash(
              algorithm: 'sha-1',
              value: 'AAF4C61DDCC5E8A2DABEDE0F3B482CD9AEA9434D',
            ),
            MtnMinecraftContentFileHash(
              algorithm: 'sha-256',
              value: '2CF24DBA5FB0A30E26E83B2AC5B9E29E1B161E5C1FA7425E73043362938B9824',
            ),
            MtnMinecraftContentFileHash(
              algorithm: 'sha-512',
              value: '9B71D224BD62F3785D96D46AD3EA3D73319BFBC2890CAADAE2DFF72519673CA72323C3D99BA5C11D7C7ACC6E14B8C5DA0C4663475C2E5C3ADEF46F73BCDEC043',
            ),
          ],
        ),
      )!;

      expect(
        integrity.checksums.keys,
        orderedEquals(<String>['md5', 'sha1', 'sha256', 'sha512']),
      );
      expect(
        integrity.checksums['sha1'],
        'aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d',
      );

      final directory = await Directory.systemTemp.createTemp();
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}hello.bin');
      await file.writeAsString('hello');

      await expectLater(integrity.validate(file), completes);
    });

    test('accepts duplicate aliases when they declare the same digest', () {
      final integrity = MtnMinecraftContentDownloadIntegrityRemVibe.fromFile(
        _file(
          size: null,
          hashes: <MtnMinecraftContentFileHash>[
            MtnMinecraftContentFileHash(
              algorithm: 'sha1',
              value: 'aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d',
            ),
            MtnMinecraftContentFileHash(
              algorithm: 'sha-1',
              value: 'AAF4C61DDCC5E8A2DABEDE0F3B482CD9AEA9434D',
            ),
          ],
        ),
      )!;

      expect(
        integrity.checksums,
        <String, String>{
          'sha1': 'aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d',
        },
      );
    });

    test('rejects conflicting aliases for the same supported algorithm', () {
      expect(
        () => MtnMinecraftContentDownloadIntegrityRemVibe.fromFile(
          _file(
            size: null,
            hashes: <MtnMinecraftContentFileHash>[
              MtnMinecraftContentFileHash(
                algorithm: 'sha1',
                value: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              ),
              MtnMinecraftContentFileHash(
                algorithm: 'sha-1',
                value: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed digest metadata for a supported algorithm', () {
      expect(
        () => MtnMinecraftContentDownloadIntegrityRemVibe.fromFile(
          _file(
            size: null,
            hashes: <MtnMinecraftContentFileHash>[
              MtnMinecraftContentFileHash(
                algorithm: 'sha256',
                value: 'not-a-sha256',
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
    });

    test('reports checksum mismatch for an existing staged file', () async {
      final integrity = MtnMinecraftContentDownloadIntegrityRemVibe.fromFile(
        _file(
          size: null,
          hashes: <MtnMinecraftContentFileHash>[
            MtnMinecraftContentFileHash(
              algorithm: 'sha1',
              value: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            ),
          ],
        ),
      )!;
      final directory = await Directory.systemTemp.createTemp();
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}hash.bin');
      await file.writeAsString('hello');

      await expectLater(
        integrity.validate(file),
        throwsA(
          isA<MtnMinecraftContentDownloadIntegrityException>().having(
            (error) => error.message,
            'message',
            contains('checksum mismatch'),
          ),
        ),
      );
    });

    test('reports a missing staged file explicitly', () async {
      final integrity = MtnMinecraftContentDownloadIntegrityRemVibe.fromFile(
        _file(size: 1),
      )!;
      final directory = await Directory.systemTemp.createTemp();
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}missing.bin');

      await expectLater(
        integrity.validate(file),
        throwsA(
          isA<MtnMinecraftContentDownloadIntegrityException>().having(
            (error) => error.message,
            'message',
            contains('is missing'),
          ),
        ),
      );
    });

    test('keeps normalized checksum expectations immutable', () {
      final integrity = MtnMinecraftContentDownloadIntegrityRemVibe.fromFile(
        _file(
          size: null,
          hashes: <MtnMinecraftContentFileHash>[
            MtnMinecraftContentFileHash(
              algorithm: 'md5',
              value: '5d41402abc4b2a76b9719d911017c592',
            ),
          ],
        ),
      )!;

      expect(
        () => integrity.checksums['sha1'] =
            'aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d',
        throwsUnsupportedError,
      );
    });
  });
}

MtnMinecraftContentFile _file({
  required int? size,
  List<MtnMinecraftContentFileHash>? hashes,
}) {
  return MtnMinecraftContentFile(
    fileName: 'example.jar',
    size: size,
    hashes: hashes,
  );
}
