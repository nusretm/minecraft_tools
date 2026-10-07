import '../model/minecraft_content_models.dart';
import '../provider/minecraft_content_provider.dart';
import '../provider/minecraft_content_provider_list.dart';
import '../provider/minecraft_content_provider_models.dart';
import 'minecraft_content_dependency_graph.dart';
import 'minecraft_content_dependency_install_plan.dart';

class MtnMinecraftContentService {
  MtnMinecraftContentService({
    Iterable<MtnMinecraftContentProvider> providers = const <MtnMinecraftContentProvider>[],
  }) : providers = MtnMinecraftContentProviderList(providers);

  final MtnMinecraftContentProviderList providers;

  Future<MtnMinecraftContentSearchResult> search(String providerName, MtnMinecraftContentSearchRequest request) {
    return providers.requireReadyFromName(providerName).search(request);
  }

  Future<List<MtnMinecraftContentSearchResult>> searchAll(MtnMinecraftContentSearchRequest request) {
    return Future.wait(
      providers.readyItems.map((provider) => provider.search(request)),
    );
  }

  Future<MtnMinecraftContent> getContent(String providerName, String id) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'Content id cannot be empty.');
    return providers.requireReadyFromName(providerName).getContent(id);
  }

  Future<MtnMinecraftContentVersion> getVersion(String providerName, String id) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'Version id cannot be empty.');
    return providers.requireReadyFromName(providerName).getVersion(id);
  }

  Future<MtnMinecraftContentVersionListResult> getVersions(String providerName, MtnMinecraftContent content, MtnMinecraftContentVersionListRequest request) {
    return providers.requireReadyFromName(providerName).getVersions(content, request);
  }

  Future<MtnMinecraftContentDependencyResolution> resolveDependency(MtnMinecraftContentDependency dependency) async {
    final resolvedVersion = dependency.version;
    if (resolvedVersion != null) return MtnMinecraftContentDependencyResolution(dependency: dependency, version: resolvedVersion);

    final providerName = dependency.provider;
    final resolvedContent = dependency.content;
    if (providerName == null) return MtnMinecraftContentDependencyResolution(dependency: dependency, content: resolvedContent);

    if (resolvedContent != null) _requireDependencyContentIdentity(dependency, providerName, resolvedContent);

    final providerVersionId = dependency.providerVersionId;
    if (providerVersionId != null && providerVersionId.isNotEmpty) {
      final version = await getVersion(providerName, providerVersionId);
      _requireDependencyContentIdentity(dependency, providerName, version.content);

      if (resolvedContent != null) {
        final resolvedContentId = _providerContentId(providerName, resolvedContent);
        final versionContentId = _providerContentId(providerName, version.content);
        if (resolvedContentId != null && versionContentId != null && resolvedContentId != versionContentId) {
          throw FormatException('Resolved dependency content $resolvedContentId does not match version owner $versionContentId for provider $providerName.');
        }
      }

      return MtnMinecraftContentDependencyResolution(dependency: dependency, version: version);
    }

    if (resolvedContent != null) return MtnMinecraftContentDependencyResolution(dependency: dependency, content: resolvedContent);

    final providerContentId = dependency.providerContentId;
    if (providerContentId == null || providerContentId.isEmpty) return MtnMinecraftContentDependencyResolution(dependency: dependency);

    final content = await getContent(providerName, providerContentId);
    _requireDependencyContentIdentity(dependency, providerName, content);
    return MtnMinecraftContentDependencyResolution(dependency: dependency, content: content);
  }

  Future<MtnMinecraftContentDependencyResolution> resolveDependencyVersion(
    MtnMinecraftContentDependency dependency,
    MtnMinecraftContentVersionSelectionRequest request,
  ) async {
    final identity = await resolveDependency(dependency);
    if (identity.versionResolved || !identity.contentResolved) return identity;

    final providerName = dependency.provider;
    final content = identity.content;
    if (providerName == null || content == null) return identity;

    const pageSize = 50;
    var page = await getVersions(
      providerName,
      content,
      MtnMinecraftContentVersionListRequest(
        gameVersions: request.gameVersions,
        modLoaders: request.modLoaders,
        releaseTypes: request.releaseTypes,
        offset: 0,
        limit: pageSize,
      ),
    );

    if (page.versions.isEmpty && !page.hasMore) return identity;
    if (!page.hasMore) return MtnMinecraftContentDependencyResolution(dependency: dependency, version: page.versions.last);

    final total = page.total;
    if (total != null) {
      if (total <= 0) return identity;

      final lastPageOffset = ((total - 1) ~/ pageSize) * pageSize;
      if (lastPageOffset != 0) {
        page = await getVersions(
          providerName,
          content,
          MtnMinecraftContentVersionListRequest(
            gameVersions: request.gameVersions,
            modLoaders: request.modLoaders,
            releaseTypes: request.releaseTypes,
            offset: lastPageOffset,
            limit: pageSize,
          ),
        );
      }

      if (page.versions.isEmpty) return identity;
      return MtnMinecraftContentDependencyResolution(dependency: dependency, version: page.versions.last);
    }

    MtnMinecraftContentVersion? latest = page.versions.isEmpty ? null : page.versions.last;
    while (page.hasMore) {
      final nextOffset = page.offset + page.limit;
      if (nextOffset <= page.offset) throw StateError('Version pagination did not advance for provider $providerName.');

      page = await getVersions(
        providerName,
        content,
        MtnMinecraftContentVersionListRequest(
          gameVersions: request.gameVersions,
          modLoaders: request.modLoaders,
          releaseTypes: request.releaseTypes,
          offset: nextOffset,
          limit: pageSize,
        ),
      );
      if (page.versions.isNotEmpty) latest = page.versions.last;
    }

    if (latest == null) return identity;
    return MtnMinecraftContentDependencyResolution(dependency: dependency, version: latest);
  }

  Future<MtnMinecraftContentDependencyGraph> resolveDependencyGraph(
    MtnMinecraftContentVersion root,
    MtnMinecraftContentVersionSelectionRequest request,
  ) async {
    final versionsByKey = <String, MtnMinecraftContentVersion>{
      root.key: root,
    };
    final versions = <MtnMinecraftContentVersion>[root];
    final edges = <MtnMinecraftContentDependencyGraphEdge>[];
    final expandedVersionKeys = <String>{};

    Future<void> expand(MtnMinecraftContentVersion source, Set<String> path) async {
      if (!expandedVersionKeys.add(source.key)) return;

      for (final dependency in source.dependencies) {
        final resolution = await resolveDependencyVersion(dependency, request);
        final resolvedVersion = resolution.version;

        if (resolvedVersion == null) {
          edges.add(
            MtnMinecraftContentDependencyGraphEdge(
              source: source,
              dependency: dependency,
              resolution: resolution,
              target: null,
              cyclic: false,
            ),
          );
          continue;
        }

        var target = versionsByKey[resolvedVersion.key];
        if (target == null) {
          target = resolvedVersion;
          versionsByKey[target.key] = target;
          versions.add(target);
        }

        final cyclic = path.contains(target.key);
        edges.add(
          MtnMinecraftContentDependencyGraphEdge(
            source: source,
            dependency: dependency,
            resolution: resolution,
            target: target,
            cyclic: cyclic,
          ),
        );

        if (cyclic || expandedVersionKeys.contains(target.key)) continue;

        await expand(
          target,
          <String>{
            ...path,
            target.key,
          },
        );
      }
    }

    await expand(root, <String>{root.key});

    return MtnMinecraftContentDependencyGraph(
      root: root,
      versions: versions,
      edges: edges,
    );
  }

  MtnMinecraftContentDependencyInstallPlan planDependencyInstall(
    MtnMinecraftContentDependencyGraph graph,
    MtnMinecraftContentDependencyInstallRequest request,
  ) {
    final optionalVersionKeys = <String>{
      for (final edge in graph.edges)
        if (edge.dependency.type == MtnMinecraftContentDependencyType.optional && edge.target != null) edge.target!.key,
    };
    for (final selectedKey in request.selectedOptionalVersionKeys) {
      if (!optionalVersionKeys.contains(selectedKey)) throw ArgumentError.value(selectedKey, 'request.selectedOptionalVersionKeys', 'Selected optional version key does not belong to a resolved optional dependency in this graph.');
    }

    final edgesBySourceKey = <String, List<MtnMinecraftContentDependencyGraphEdge>>{};
    for (final edge in graph.edges) {
      edgesBySourceKey.putIfAbsent(edge.source.key, () => <MtnMinecraftContentDependencyGraphEdge>[]).add(edge);
    }

    final selectedOptionalVersionKeys = request.selectedOptionalVersionKeys.toSet();
    final installVersions = <MtnMinecraftContentVersion>[];
    final installVersionsByKey = <String, MtnMinecraftContentVersion>{};
    final installEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final optionalEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final selectedOptionalEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final bundledEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final toolEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final incompatibleEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final unresolvedInstallEdges = <MtnMinecraftContentDependencyGraphEdge>[];
    final expandedVersionKeys = <String>{};

    void includeVersion(MtnMinecraftContentVersion version) {
      if (installVersionsByKey.containsKey(version.key)) return;
      installVersionsByKey[version.key] = version;
      installVersions.add(version);
    }

    void expand(MtnMinecraftContentVersion source) {
      if (!expandedVersionKeys.add(source.key)) return;

      for (final edge in edgesBySourceKey[source.key] ?? const <MtnMinecraftContentDependencyGraphEdge>[]) {
        final target = edge.target;

        switch (edge.dependency.type) {
          case MtnMinecraftContentDependencyType.required:
          case MtnMinecraftContentDependencyType.embeddedLibrary:
            if (target == null) {
              unresolvedInstallEdges.add(edge);
              continue;
            }
            installEdges.add(edge);
            includeVersion(target);
            expand(target);
            break;

          case MtnMinecraftContentDependencyType.optional:
            optionalEdges.add(edge);
            if (target == null || !selectedOptionalVersionKeys.contains(target.key)) continue;
            selectedOptionalEdges.add(edge);
            installEdges.add(edge);
            includeVersion(target);
            expand(target);
            break;

          case MtnMinecraftContentDependencyType.bundled:
            bundledEdges.add(edge);
            break;

          case MtnMinecraftContentDependencyType.tool:
            toolEdges.add(edge);
            break;

          case MtnMinecraftContentDependencyType.incompatible:
            incompatibleEdges.add(edge);
            break;
        }
      }
    }

    includeVersion(graph.root);
    expand(graph.root);

    final conflicts = <MtnMinecraftContentDependencyInstallConflict>[];
    final versionsByContentKey = <String, List<MtnMinecraftContentVersion>>{};
    for (final version in installVersions) {
      versionsByContentKey.putIfAbsent(version.content.key, () => <MtnMinecraftContentVersion>[]).add(version);
    }
    for (final entry in versionsByContentKey.entries) {
      if (entry.value.length < 2) continue;
      conflicts.add(
        MtnMinecraftContentDependencyInstallConflictMultipleVersions(
          contentKey: entry.key,
          versions: entry.value,
        ),
      );
    }

    for (final edge in incompatibleEdges) {
      final dependency = edge.dependency;
      final providerVersionId = dependency.providerVersionId;
      final exactVersion = dependency.version;
      final exactDeclaration = exactVersion != null || (providerVersionId != null && providerVersionId.isNotEmpty);

      if (exactDeclaration) {
        final versionKey = exactVersion?.key ?? edge.target?.key;
        final conflictingVersion = versionKey == null ? null : installVersionsByKey[versionKey];
        if (conflictingVersion != null) {
          conflicts.add(
            MtnMinecraftContentDependencyInstallConflictIncompatible(
              edge: edge,
              conflictingVersion: conflictingVersion,
            ),
          );
        }
        continue;
      }

      final contentKey = edge.resolution.content?.key ?? dependency.content?.key ?? edge.target?.content.key;
      if (contentKey == null) continue;

      for (final installedVersion in installVersions) {
        if (installedVersion.content.key != contentKey) continue;
        conflicts.add(
          MtnMinecraftContentDependencyInstallConflictIncompatible(
            edge: edge,
            conflictingVersion: installedVersion,
          ),
        );
      }
    }

    return MtnMinecraftContentDependencyInstallPlan(
      root: graph.root,
      installVersions: installVersions,
      installEdges: installEdges,
      optionalEdges: optionalEdges,
      selectedOptionalEdges: selectedOptionalEdges,
      bundledEdges: bundledEdges,
      toolEdges: toolEdges,
      incompatibleEdges: incompatibleEdges,
      unresolvedInstallEdges: unresolvedInstallEdges,
      conflicts: conflicts,
    );
  }

  void _requireDependencyContentIdentity(MtnMinecraftContentDependency dependency, String providerName, MtnMinecraftContent content) {
    final expected = dependency.providerContentId;
    if (expected == null || expected.isEmpty) return;

    final actual = _providerContentId(providerName, content);
    if (actual != expected) throw FormatException('Resolved dependency content id $actual does not match expected $providerName content id $expected.');
  }

  String? _providerContentId(String providerName, MtnMinecraftContent content) {
    for (final metadata in content.providers) {
      if (metadata.provider == providerName) return metadata.id;
    }
    return null;
  }
}
