import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:inspirobot/inspirobot.dart';
import 'package:nyxx/nyxx.dart';
import 'package:prometheus_client/prometheus_client.dart';
import 'package:prometheus_client/runtime_metrics.dart' as runtime_metrics;
import 'package:prometheus_client_shelf/shelf_handler.dart';
import 'package:shelf/shelf_io.dart';

final inspirobot = InspiroBot();
final homechannel = Snowflake(836643866358186046);
final me = Snowflake(836241654557966386);

final inspirations = Counter(
  name: 'inspiriererin_inspirations',
  help: 'How many times people were inspired',
  labelNames: ['author'],
);

final logs = Counter(
  name: 'inspiriererin_logs',
  help: 'How many times people have logged channels',
  labelNames: ['author'],
);

final rateLimits = Counter(
  name: 'inspiriererin_rate_limits',
  help: 'How many times we got rate limited',
);

String authorToString(IMessageAuthor a) => '${a.username}#${a.discriminator}';

Future<void> inspire(ITextChannel c, String a) async {
  final url = await inspirobot.generate();
  final r = await c.sendMessage(MessageBuilder.content(url.toString()));
  await r.createReaction(UnicodeEmoji('⏭'));
  await r.createReaction(UnicodeEmoji('🔼'));
  r.createReaction(UnicodeEmoji('🔽'));
  print('Inspired $a at ${r.url}: $url');
  inspirations.labels([a]).inc();
}

Stream<IMessage> accumulateMessagesBefore(IMessage message) async* {
  final msgs = message.channel.downloadMessages(before: message.id, limit: 100);
  IMessage? msg;
  await for (msg in msgs) {
    yield msg;
  }
  if (msg != null) {
    yield* accumulateMessagesBefore(msg);
  }
}

Map<String, dynamic> msgToJson(IMessage m) => {
      'author': '${authorToString(m.author)} ${m.author.id.id}',
      'content': m.content,
      'created': m.createdAt.toIso8601String(),
      'edited': m.editedTimestamp?.toIso8601String(),
      'attachments': m.attachments
          .map((a) => {
                'description': a.description,
                'name': a.filename,
                'url': a.url,
              })
          .toList(),
    };

String msgToText(IMessage m) =>
    '[${m.editedTimestamp ?? m.createdAt}] ${authorToString(m.author)}: ${m.content}'
        .replaceRange(20, 25, '');

void main(List<String> argv) {
  runtime_metrics.register();
  inspirations.register();
  logs.register();
  rateLimits.register();
  serve(prometheusHandler(), InternetAddress.anyIPv6, 8989).then((s) =>
      print('Serving metrics at http://${s.address.host}:${s.port}/metrics'));

  final client = NyxxFactory.createNyxxWebsocket(
      argv.first, GatewayIntents.allUnprivileged)
    ..registerPlugin(Logging())
    ..registerPlugin(CliIntegration())
    ..connect();
  client.eventsWs
    ..onRateLimited.listen((event) {
      Future.delayed(
          Duration(seconds: Random().nextInt(60)),
          () => client
              .fetchChannel(homechannel)
              .then((c) => c as ITextChannel)
              .then((c) => c.sendMessage(MessageBuilder.content(
                  'Hilfe, ich wurde limitiert! ${event.response}')))
              .then((_) => rateLimits.inc()));
    })
    ..onMessageReceived.listen((event) async {
      final msg = event.message;
      final a = msg.author;
      final channel = await msg.channel.getOrDownload();
      final content = msg.content.toLowerCase();
      if (content == 'inspire' ||
          (channel.id == homechannel && content == 'i')) {
        inspire(channel, authorToString(a));
      } else if (content.startsWith('\$ log')) {
        final args = content.split(' ');
        final message = args.length < 4
            ? event.message
            : await client
                .fetchChannel(Snowflake(args[2]))
                .then((c) => c as ITextChannel)
                .then((c) => c.getMessage(Snowflake(args[3]))!);
        // TODO: better message
        print('Logging ${message.channel} for ${authorToString(a)}...');
        final msgs = await accumulateMessagesBefore(message).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        channel
            .sendMessage(MessageBuilder()
              ..addBytesAttachment(
                  utf8.encode(JsonEncoder.withIndent(' ')
                          .convert(msgs.map(msgToJson).toList()) +
                      '\n'),
                  '${channel.id.id}.json')
              ..addBytesAttachment(
                  utf8.encode(msgs.map(msgToText).join('\n') + '\n'),
                  '${channel.id.id}.txt'))
            .then((_) => logs.labels([authorToString(a)]).inc());
      }
    })
    ..onMessageReactionAdded.listen((event) async {
      final channel = await event.channel.getOrDownload();
      // TODO: ask nyxx people if they couldn't conditionally fetch event.message
      final msg = await channel.fetchMessage(event.messageId);
      final author = msg.author;
      final user = await event.user.getOrDownload();
      if (author.id == me &&
          user.id != author.id &&
          event.emoji is UnicodeEmoji &&
          (event.emoji as UnicodeEmoji).code == '⏭')
        inspire(channel, authorToString(user));
    });
}
