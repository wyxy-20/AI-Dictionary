import 'dart:convert';

import 'package:ai_dictionary/core/config/app_config.dart';
import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/database/history_dao.dart';
import 'package:ai_dictionary/database/term_dao.dart';
import 'package:ai_dictionary/database/version_dao.dart';
import 'package:ai_dictionary/models/term.dart';
import 'package:ai_dictionary/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'test_utils.dart';

Term makeTerm(String en, String zh) {
  return Term(
    englishName: en,
    chineseName: zh,
    category: '测试分类',
    difficulty: 1,
    shortDescription: '$en 简介',
    detailDescription: '$en 详细解释',
    application: const ['场景'],
    relatedTerms: const ['AI'],
    firstCreated: 0,
  );
}

Map<String, dynamic> termJson(Term t) => t.toJson();

void main() {
  late AppDatabase db;

  setUp(() async {
    ensureSqliteAvailable();
    db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
    await db.openInMemory();
    await TermDao(db).insertAll([
      makeTerm('AI', '人工智能'),
      makeTerm('Agent', '智能体'),
      makeTerm('RAG', '检索增强生成'),
    ]);
    // 制造一条收藏 + 一条历史，验证更新不破坏用户数据
    final terms = await TermDao(db).getAll();
    final ai = terms.firstWhere((t) => t.englishName == 'AI');
    await TermDao(db).setFavorite(ai.id!, true);
    await HistoryDao(db).recordView(ai.id!);
  });

  tearDown(() async {
    await db.close();
  });

  UpdateService serviceWith(
    Future<http.Response> Function(http.Request request) handler, {
    String? baseUrl,
  }) {
    return UpdateService(
      db,
      client: MockClient(handler),
      baseUrl: baseUrl ?? 'http://dictionary.test',
    );
  }

  http.Response jsonResponse(Object body, {int status = 200}) {
    return http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});
  }

  test('本地版本最新：跳过更新，正常进入', () async {
    final service = serviceWith((request) async {
      if (request.url.path.endsWith('version.json')) {
        return jsonResponse({
          'version': '1.0.0',
          'update_time': '2026-08-08',
          'terms_count': 3,
        });
      }
      return jsonResponse(<String>[]);
    });

    final result = await service.syncIfNeeded();

    expect(result.status, 'upToDate');
    expect(result.isUpdated, isFalse);
    expect(await TermDao(db).count(), 3);

    // 检查时间已记录
    final version = await VersionDao(db).get();
    expect(version!.lastCheckTime, greaterThan(0));
  });

  test('远程存在新版本：自动增量更新，新增词条可搜索', () async {
    final existing = await TermDao(db).getAll();
    final remoteTerms = [
      ...existing.map(termJson),
      termJson(makeTerm('MCP', '模型上下文协议')),
      termJson(makeTerm('LoRA', '低秩适配')),
    ];
    final service = serviceWith((request) async {
      if (request.url.path.endsWith('version.json')) {
        return jsonResponse({
          'version': '1.1.0',
          'update_time': '2026-08-08',
          'terms_count': remoteTerms.length,
        });
      }
      return jsonResponse({'version': '1.1.0', 'terms': remoteTerms});
    });

    final result = await service.syncIfNeeded();

    expect(result.status, 'updated');
    expect(result.addedCount, 2);
    expect(await TermDao(db).count(), 5);

    final all = await TermDao(db).getAll();
    final names = all.map((t) => t.englishName).toSet();
    expect(names, containsAll(['MCP', 'LoRA']));

    // 用户数据完好：收藏与历史仍在
    final ai = all.firstWhere((t) => t.englishName == 'AI');
    expect(ai.favorite, isTrue);
    expect((await HistoryDao(db).getRecentTerms()).length, 1);

    // 本地版本已记录为远程版本
    final version = await VersionDao(db).get();
    expect(version!.version, '1.1.0');
  });

  test('24 小时内不重复检查；force 可强制检查', () async {
    var versionCalls = 0;
    final remoteTerms = [
      termJson(makeTerm('MCP', '模型上下文协议')),
    ];
    final service = serviceWith((request) async {
      if (request.url.path.endsWith('version.json')) {
        versionCalls++;
        return jsonResponse({
          'version': '1.1.0',
          'update_time': '2026-08-08',
          'terms_count': remoteTerms.length,
        });
      }
      return jsonResponse(remoteTerms);
    });

    // 第一次：正常更新
    await service.syncIfNeeded();
    expect(versionCalls, 1);

    // 第二次（24 小时内）：跳过，不请求远程
    final result = await service.syncIfNeeded();
    expect(result.status, 'skipped');
    expect(versionCalls, 1);
    expect(await TermDao(db).count(), 4);

    // force 强制检查
    final forced = await service.syncIfNeeded(force: true);
    expect(forced.status, 'upToDate');
    expect(versionCalls, 2);
    expect(await TermDao(db).count(), 4);
  });

  test('无网络：静默降级到本地词库，不抛错', () async {
    final service = serviceWith((request) async {
      throw http.ClientException('Connection refused');
    });

    final result = await service.syncIfNeeded();

    expect(result.status, 'failed');
    expect(await TermDao(db).count(), 3);
    final all = await TermDao(db).getAll();
    expect(all.firstWhere((t) => t.englishName == 'AI').favorite, isTrue);
  });

  test('远程返回 500：降级到本地词库', () async {
    final service = serviceWith((request) async {
      return http.Response('server error', 500);
    });

    final result = await service.syncIfNeeded();
    expect(result.status, 'failed');
    expect(await TermDao(db).count(), 3);
  });

  test('terms.json 数组格式同样支持', () async {
    final service = serviceWith((request) async {
      if (request.url.path.endsWith('version.json')) {
        return jsonResponse({
          'version': '1.2.0',
          'update_time': '2026-08-08',
          'terms_count': 1,
        });
      }
      return jsonResponse([termJson(makeTerm('Embedding', '嵌入'))]);
    });

    final result = await service.syncIfNeeded();
    expect(result.status, 'updated');
    expect(result.addedCount, 1);
    expect(await TermDao(db).count(), 4);
  });

  test('远程词条内容变化：更新内容并提升 version，收藏保留', () async {
    final existing = await TermDao(db).getAll();
    final remoteTerms = existing.map((t) {
      if (t.englishName == 'AI') {
        return termJson(Term(
          englishName: 'AI',
          chineseName: '人工智能',
          category: '基础概念',
          difficulty: 2,
          shortDescription: '新的简介',
          detailDescription: '新的详细解释内容',
          application: const ['新场景'],
          relatedTerms: const ['LLM', 'AGI'],
          firstCreated: 0,
        ));
      }
      return termJson(t);
    }).toList();

    final service = serviceWith((request) async {
      if (request.url.path.endsWith('version.json')) {
        return jsonResponse({
          'version': '1.1.0',
          'update_time': '2026-08-08',
          'terms_count': remoteTerms.length,
        });
      }
      return jsonResponse(remoteTerms);
    });

    final result = await service.syncIfNeeded();

    expect(result.status, 'updated');
    expect(result.addedCount, 0);
    expect(result.updatedCount, 1);
    expect(await TermDao(db).count(), 3);

    final all = await TermDao(db).getAll();
    final ai = all.firstWhere((t) => t.englishName == 'AI');
    expect(ai.detailDescription, '新的详细解释内容');
    expect(ai.version, 2, reason: '内容变化后 version 应提升');
    expect(ai.favorite, isTrue, reason: '收藏数据不能丢失');
  });

  test('启动频率配置合理', () {
    expect(AppConfig.remoteCheckInterval.inHours, 24);
    expect(AppConfig.remoteTimeout.inSeconds, lessThanOrEqualTo(10));
  });
}
