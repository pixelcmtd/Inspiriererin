import 'package:http/http.dart' as http;
import 'package:nyxx/nyxx.dart';

final api = Uri.parse('https://inspirobot.me/api?generate=true');

Future<void> inspire(TextChannel c, String u, int d) async {
  final url = (await http.get(api)).body;
  final r = await c.sendMessage(MessageBuilder.content(url));
  await r.createReaction(UnicodeEmoji('⏭'));
  await r.createReaction(UnicodeEmoji('🔼'));
  r.createReaction(UnicodeEmoji('🔽'));
  print('Inspired $u#$d at ${r.url}: $url');
}

void main(List<String> argv) {
  Nyxx(argv.first, GatewayIntents.allUnprivileged)
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
