import 'package:attendance_app/services/app_realtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake channel transport for pooling tests.
class _FakeChannels {
  final List<String> opened = [];
  final List<String> removed = [];
  final Map<String, void Function()> emit = {};
  final Map<RealtimeChannel, String> _topicOf = {};

  void remove(RealtimeChannel channel) => removed.add(_topicOf[channel]!);

  RealtimeChannel build({
    required String topic,
    required String table,
    String? filterColumn,
    String? filterValue,
    required void Function() onEvent,
  }) {
    opened.add(topic);
    emit[topic] = onEvent;
    final channel = RealtimeChannel(topic, RealtimeClient(''));
    _topicOf[channel] = topic;
    return channel;
  }
}

void main() {
  late _FakeChannels fake;

  setUp(() {
    fake = _FakeChannels();
    AppRealtime.debugSetChannelBuilder(fake.build, remover: fake.remove);
  });

  tearDown(() {
    AppRealtime.disposeAll();
    AppRealtime.debugSetChannelBuilder(null);
  });

  test('two subscribers on the same topic share one channel', () {
    var bellReloads = 0;
    var screenReloads = 0;

    final bell = AppRealtime.subscribeMyNotifications(
      userId: 'u1',
      onReload: () => bellReloads++,
    );
    final screen = AppRealtime.subscribeMyNotifications(
      userId: 'u1',
      onReload: () => screenReloads++,
    );

    expect(fake.opened, ['app_notifications:user:u1']);
    expect(AppRealtime.debugTopicCount(), 1);

    fake.emit['app_notifications:user:u1']!();
    expect(bellReloads, 1);
    expect(screenReloads, 1);

    expect(bell, isNot(same(screen)));
  });

  test('different users get separate channels', () {
    AppRealtime.subscribeMyLeaves(userId: 'u1', onReload: () {});
    AppRealtime.subscribeMyLeaves(userId: 'u2', onReload: () {});

    expect(fake.opened, [
      'leave_requests:user:u1',
      'leave_requests:user:u2',
    ]);
  });

  test('releasing one subscriber stops only its callback', () {
    var first = 0;
    var second = 0;

    final a = AppRealtime.subscribeAdminLeaves(onReload: () => first++);
    AppRealtime.subscribeAdminLeaves(onReload: () => second++);

    AppRealtime.disposeChannel(a);

    fake.emit['leave_requests:all']!();
    expect(first, 0);
    expect(second, 1);
    expect(AppRealtime.debugTopicCount(), 1);
  });

  test('re-subscribing during teardown reuses the open channel', () async {
    final first = AppRealtime.subscribeAdminAttendance(onReload: () {});
    AppRealtime.disposeChannel(first);

    // Same event-loop turn as a screen swap.
    var reloads = 0;
    AppRealtime.subscribeAdminAttendance(onReload: () => reloads++);
    await Future<void>.delayed(Duration.zero);

    expect(fake.opened, ['attendance:all']);
    expect(AppRealtime.debugTopicCount(), 1);

    fake.emit['attendance:all']!();
    expect(reloads, 1);
  });

  test('releasing the last subscriber drops the topic', () async {
    final only = AppRealtime.subscribeMyClaims(userId: 'u1', onReload: () {});
    expect(AppRealtime.debugTopicCount(), 1);

    AppRealtime.disposeChannel(only);
    await Future<void>.delayed(Duration.zero);

    expect(AppRealtime.debugTopicCount(), 0);
    expect(fake.removed, ['expense_claims:user:u1']);
  });

  test('double dispose is a no-op', () async {
    final sub = AppRealtime.subscribeMyAttendance(
      userId: 'u1',
      onReload: () {},
    );
    AppRealtime.disposeChannel(sub);
    AppRealtime.disposeChannel(sub);
    await Future<void>.delayed(Duration.zero);

    expect(AppRealtime.debugTopicCount(), 0);
    expect(fake.removed, hasLength(1));
  });
}
