import 'package:minecraft_info_provider/minecraft_info_provider.dart';
import 'package:test/test.dart';

void main() {
  group('Minecraft text core', () {
    test('exposes classic named colors and serialization', () {
      expect(
        MtnMinecraftTextColor.darkGray.type,
        MtnMinecraftTextColorType.named,
      );
      expect(MtnMinecraftTextColor.darkGray.isNamed, isTrue);
      expect(MtnMinecraftTextColor.darkGray.isRgb, isFalse);
      expect(MtnMinecraftTextColor.darkGray.code, '8');
      expect(MtnMinecraftTextColor.darkGray.name, 'dark_gray');
      expect(MtnMinecraftTextColor.darkGray.rgb, 0x555555);
      expect(MtnMinecraftTextColor.darkGray.hex, '#555555');
      expect(MtnMinecraftTextColor.darkGray.toString(), '&8');
      expect(MtnMinecraftTextColor.darkGray.toServerString(), '§8');

      expect(
        MtnMinecraftTextColor.fromCode('§C'),
        MtnMinecraftTextColor.red,
      );
      expect(
        MtnMinecraftTextColor.fromCode('&c'),
        MtnMinecraftTextColor.red,
      );
      expect(
        MtnMinecraftTextColor.fromCode('c'),
        MtnMinecraftTextColor.red,
      );
      expect(MtnMinecraftTextColor.tryFromCode('z'), isNull);
      expect(
        () => MtnMinecraftTextColor.fromCode('z'),
        throwsFormatException,
      );
    });

    test('supports arbitrary RGB colors without nullable rendering state', () {
      final MtnMinecraftTextColor color =
          MtnMinecraftTextColor.rgb(18, 171, 239);

      expect(color.type, MtnMinecraftTextColorType.rgbColor);
      expect(color.isNamed, isFalse);
      expect(color.isRgb, isTrue);
      expect(color.code, isNull);
      expect(color.name, isNull);
      expect(color.rgb, 0x12ABEF);
      expect(color.hex, '#12ABEF');
      expect(color.toString(), '&#12ABEF');
      expect(color.toServerString(), '§x§1§2§A§B§E§F');

      expect(MtnMinecraftTextColor.fromCode('#12ABEF'), color);
      expect(MtnMinecraftTextColor.fromCode('&#12ABEF'), color);
      expect(
        MtnMinecraftTextColor.fromCode('&x&1&2&A&B&E&F'),
        color,
      );
      expect(
        MtnMinecraftTextColor.fromCode('§x§1§2§A§B§E§F'),
        color,
      );
    });

    test('segments formatted source into render-ready items', () {
      final MtnMinecraftText text = MtnMinecraftText(
        text:
            '§8[§4Hata§8] §cMaden bulunamadı! §7Lütfen §e/warp maden §7yazın.',
      );

      expect(
        text.plainText,
        '[Hata] Maden bulunamadı! Lütfen /warp maden yazın.',
      );
      expect(text.items, hasLength(7));

      expect(text.items[0].text, '[');
      expect(text.items[0].color, MtnMinecraftTextColor.darkGray);
      expect(text.items[1].text, 'Hata');
      expect(text.items[1].color, MtnMinecraftTextColor.darkRed);
      expect(text.items[2].text, '] ');
      expect(text.items[2].color, MtnMinecraftTextColor.darkGray);
      expect(text.items[3].text, 'Maden bulunamadı! ');
      expect(text.items[3].color, MtnMinecraftTextColor.red);
      expect(text.items[4].text, 'Lütfen ');
      expect(text.items[4].color, MtnMinecraftTextColor.gray);
      expect(text.items[5].text, '/warp maden ');
      expect(text.items[5].color, MtnMinecraftTextColor.yellow);
      expect(text.items[6].text, 'yazın.');
      expect(text.items[6].color, MtnMinecraftTextColor.gray);

      for (final MtnMinecraftTextItem item in text.items) {
        expect(item.bold, isFalse);
        expect(item.italic, isFalse);
        expect(item.underlined, isFalse);
        expect(item.strikethrough, isFalse);
        expect(item.obfuscated, isFalse);
      }
    });

    test('resolves formatting state and reset before exposing items', () {
      final MtnMinecraftText text =
          MtnMinecraftText(text: '§c§lBold red §nUnder§r Plain');

      expect(text.items, hasLength(3));

      expect(text.items[0].text, 'Bold red ');
      expect(text.items[0].color, MtnMinecraftTextColor.red);
      expect(text.items[0].bold, isTrue);
      expect(text.items[0].underlined, isFalse);

      expect(text.items[1].text, 'Under');
      expect(text.items[1].color, MtnMinecraftTextColor.red);
      expect(text.items[1].bold, isTrue);
      expect(text.items[1].underlined, isTrue);

      expect(text.items[2].text, ' Plain');
      expect(text.items[2].color, MtnMinecraftTextColor.white);
      expect(text.items[2].bold, isFalse);
      expect(text.items[2].underlined, isFalse);
    });

    test('color codes clear prior classic format state', () {
      final MtnMinecraftText text =
          MtnMinecraftText(text: '§lBold§cRed');

      expect(text.items, hasLength(2));
      expect(text.items[0].bold, isTrue);
      expect(text.items[1].color, MtnMinecraftTextColor.red);
      expect(text.items[1].bold, isFalse);
    });

    test('text remains source of truth after mutation', () {
      final MtnMinecraftText text = MtnMinecraftText(text: '§aOld');

      expect(text.plainText, 'Old');
      expect(text.items.single.color, MtnMinecraftTextColor.green);

      text.text = '§cNew';

      expect(text.plainText, 'New');
      expect(text.items.single.text, 'New');
      expect(text.items.single.color, MtnMinecraftTextColor.red);
    });

    test('malformed and unknown section codes remain literal', () {
      final MtnMinecraftText text =
          MtnMinecraftText(text: 'A§zB§x§1broken§');

      expect(text.plainText, 'A§zB§x§1broken§');
      expect(text.items.single.color, MtnMinecraftTextColor.white);
    });

    test('parses classic RGB section sequence and returns immutable items', () {
      final MtnMinecraftText text =
          MtnMinecraftText(text: '§x§1§2§A§B§E§FHex');

      expect(text.items.single.text, 'Hex');
      expect(text.items.single.color.hex, '#12ABEF');
      expect(
        () => text.items.add(
          const MtnMinecraftTextItem(
            text: 'x',
            style: MtnMinecraftTextStyle.defaults,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('fromItems produces a source string that resolves back to styles', () {
      final MtnMinecraftText source = MtnMinecraftText.fromItems(
        <MtnMinecraftTextItem>[
          const MtnMinecraftTextItem(
            text: 'Error',
            style: MtnMinecraftTextStyle(
              color: MtnMinecraftTextColor.red,
              bold: true,
            ),
          ),
          const MtnMinecraftTextItem(
            text: '!',
            style: MtnMinecraftTextStyle(
              color: MtnMinecraftTextColor.yellow,
            ),
          ),
        ],
      );

      expect(source.plainText, 'Error!');
      expect(source.items, hasLength(2));
      expect(source.items[0].color, MtnMinecraftTextColor.red);
      expect(source.items[0].bold, isTrue);
      expect(source.items[1].color, MtnMinecraftTextColor.yellow);
      expect(source.items[1].bold, isFalse);
    });
  });
}
