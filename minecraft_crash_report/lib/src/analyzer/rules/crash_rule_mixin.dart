import '../../model/crash_analysis.dart';
import '../crash_rule.dart';

final class MtnMinecraftCrashRuleMixin extends MtnMinecraftCrashRuleAbs {
  const MtnMinecraftCrashRuleMixin();

  static final RegExp _owner = RegExp(r'(?:\bfrom mod\s+|\bMixin apply for mod\s+)([a-z][a-z0-9_-]*)\b', caseSensitive: false);
  static final RegExp _qualifiedMixin = RegExp(r'\.mixins?\.json\s*:\s*([a-z][\w.]*)', caseSensitive: false);
  static final RegExp _configOnly = RegExp(r'\.mixins?\.json\s*:\s*$', caseSensitive: false);
  static final RegExp _target = RegExp(r'(?:->\s*|\btarget(?: class)?\s+)([A-Za-z_$][\w.$/]+)');

  @override
  Iterable<MtnMinecraftCrashFinding> evaluate(MtnMinecraftCrashRuleContext context) sync* {
    final Set<String> emitted = {};
    for (final MtnMinecraftCrashEvidence anchor in context.diagnosticLines) {
      final String text = anchor.text;
      final bool injection = context.hasException(anchor, RegExp(r'\b(?:InjectionError|InvalidInjectionException)$')) ||
          context.diagnosticText(anchor).startsWith('Critical injection failure');
      final bool apply = context.hasException(anchor, RegExp(r'\b(?:MixinApplyError|InvalidMixinException|MixinTransformerError)$')) ||
          RegExp(r'^Mixin apply for mod .* failed', caseSensitive: false).hasMatch(context.diagnosticText(anchor));
      if ((!injection && !apply) || text.trimLeft().startsWith('at ')) continue;
      final List<MtnMinecraftCrashEvidence> block = context.diagnosticBlock(anchor);
      final Map<String, MtnMinecraftCrashEvidence> owners = {};
      for (final MtnMinecraftCrashEvidence line in block) {
        for (final RegExpMatch match in _owner.allMatches(line.text)) {
          owners[match.group(1)!] = line;
        }
      }
      final MtnMinecraftCrashType type = injection ? MtnMinecraftCrashType.mixinInjection : MtnMinecraftCrashType.mixinApply;
      final String key = '${type.name}:${owners.keys.join(',')}';
      if (!emitted.add(key)) continue;
      final List<MtnMinecraftCrashModFinding> suspected = [];
      final List<MtnMinecraftCrashModFinding> related = [];
      final List<MtnMinecraftCrashRecommendation> recommendations = [];
      for (final MapEntry<String, MtnMinecraftCrashEvidence> owner in owners.entries) {
        suspected.add(context.attribution(owner.key, MtnMinecraftCrashConfidence.high, [owner.value, anchor]));
        recommendations.add(MtnMinecraftCrashRecommendation(MtnMinecraftCrashRecommendationType.disableModAndRetry, modId: owner.key));
      }
      final Set<String> relatedIds = {};
      bool nextMixin = false;
      for (final MtnMinecraftCrashEvidence line in block) {
        final List<String> symbols = [
          for (final RegExpMatch match in _qualifiedMixin.allMatches(line.text)) match.group(1)!,
          for (final RegExpMatch match in _target.allMatches(line.text)) match.group(1)!,
          if (nextMixin) line.text.trim(),
        ];
        nextMixin = _configOnly.hasMatch(line.text);
        for (final String symbol in symbols) {
          final List<String> segments = symbol.toLowerCase().split(RegExp(r'[./]'));
          for (final String id in context.mods.keys) {
            if (const ['minecraft', 'java', 'fabricloader'].contains(id) || owners.containsKey(id) ||
                !segments.contains(id.toLowerCase()) || !relatedIds.add(id)) {
              continue;
            }
            related.add(context.attribution(id, MtnMinecraftCrashConfidence.medium, [line]));
          }
        }
      }
      if (recommendations.isEmpty) {
        recommendations.add(const MtnMinecraftCrashRecommendation(MtnMinecraftCrashRecommendationType.checkModCompatibility));
      }
      yield MtnMinecraftCrashFinding(type: type, confidence: MtnMinecraftCrashConfidence.high,
        evidence: block, suspectedMods: suspected, relatedMods: related, recommendations: recommendations);
    }
  }
}
