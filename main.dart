import 'package:inspirobot/inspirobot.dart';
import 'package:nyxx/nyxx.dart';

final inspirobot = InspiroBot();

Future<void> inspire(ITextChannel c, String u, int d) async {
  final url = await inspirobot.generate();
  final r = await c.sendMessage(MessageBuilder.content(url.toString()));
  await r.createReaction(UnicodeEmoji('⏭'));
  await r.createReaction(UnicodeEmoji('🔼'));
  r.createReaction(UnicodeEmoji('🔽'));
  print('Inspired $u#$d at ${r.url}: $url');
}

void main(List<String> argv) {
  (NyxxFactory.createNyxxWebsocket(argv.first, GatewayIntents.allUnprivileged)
        ..registerPlugin(Logging())
        ..registerPlugin(CliIntegration())
        ..registerPlugin(IgnoreExceptions())
        ..connect())
      .eventsWs
    ..onMessageReceived.listen((event) async {
      final msg = event.message;
      final a = msg.author;
      final channel = await msg.channel.getOrDownload();
      final content = msg.content.toLowerCase();
      if (content == 'inspire' ||
          (channel.id == Snowflake(836643866358186046) && content == 'i')) {
        inspire(channel, a.username, a.discriminator);
      }
    })
    ..onMessageReactionAdded.listen((event) async {
      final channel = await event.channel.getOrDownload();
      // TODO: ask nyxx people if they couldn't conditionally fetch event.message
      final msg = await channel.fetchMessage(event.messageId);
      final author = msg.author;
      final user = await event.user.getOrDownload();
      if (author.id == Snowflake(836241654557966386) &&
          user.id != author.id &&
          event.emoji is UnicodeEmoji &&
          (event.emoji as UnicodeEmoji).code == '⏭')
        inspire(channel, user.username, user.discriminator);
    });
}
