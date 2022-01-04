import 'dart:convert';
import 'dart:math';

import 'package:inspirobot/inspirobot.dart';
import 'package:nyxx/nyxx.dart';

final inspirobot = InspiroBot();
final homechannel = Snowflake(836643866358186046);
final me = Snowflake(836241654557966386);

String authorToString(IMessageAuthor a) => '${a.username}#${a.discriminator}';

Future<void> inspire(ITextChannel c, String a) async {
  final url = await inspirobot.generate();
  final r = await c.sendMessage(MessageBuilder.content(url.toString()));
  await r.createReaction(UnicodeEmoji('⏭'));
  await r.createReaction(UnicodeEmoji('🔼'));
  r.createReaction(UnicodeEmoji('🔽'));
  print('Inspired $a at ${r.url}: $url');
}

Stream<IMessage> accumulateMessagesBefore(IMessage message) async* {
  final msgs =
      message.channel.downloadMessages(before: message.id).asBroadcastStream();
  yield* msgs;
  if (!(await msgs.isEmpty)) {
    yield* accumulateMessagesBefore(await msgs.last);
  }
}

Map<String, dynamic> msgToJson(IMessage m) => {
      'author': '${authorToString(m.author)} ${m.author.id.id}',
      'content': m.content,
      'created': m.createdAt.toIso8601String(),
      'edited': m.editedTimestamp?.toIso8601String(),
      'attachments': m.attachments
          .map((m) => {
                'description': m.description,
                'name': m.filename,
                'url': m.url,
              })
          .toList(),
    };

String msgToText(IMessage m) =>
    '[${m.editedTimestamp ?? m.createdAt}] ${authorToString(m.author)}: ${m.content}'
        .replaceRange(20, 25, '');

void main(List<String> argv) {
  final client = NyxxFactory.createNyxxWebsocket(
      argv.first, GatewayIntents.allUnprivileged)
    ..registerPlugin(Logging())
    ..registerPlugin(CliIntegration())
    ..registerPlugin(IgnoreExceptions())
    ..connect();
  client.eventsWs
    ..onRateLimited.listen((event) {
      Future.delayed(
          Duration(seconds: Random().nextInt(60)),
          () => client
              .fetchChannel(homechannel)
              .then((c) => c as ITextChannel)
              .then((c) => c.sendMessage(MessageBuilder.content(
                  'Hilfe, ich wurde limitiert! ${event.response}'))));
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
        channel.sendMessage(MessageBuilder()
          ..addBytesAttachment(
              utf8.encode(JsonEncoder.withIndent(' ')
                      .convert(msgs.map(msgToJson).toList()) +
                  '\n'),
              '${channel.id.id}.json')
          ..addBytesAttachment(
              utf8.encode(msgs.map(msgToText).join('\n') + '\n'),
              '${channel.id.id}.txt'));
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
