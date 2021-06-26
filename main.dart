import 'package:http/http.dart' as http;
import 'package:nyxx/nyxx.dart';

final api = Uri.parse('https://inspirobot.me/api?generate=true');

void main(List<String> argv) {
  Nyxx(argv.first, GatewayIntents.allUnprivileged)
    ..onMessageReceived.listen((event) async {
      final msg = event.message;
      final a = msg.author;
      final channel = await msg.channel.getOrDownload();
      final content = msg.content.toLowerCase();
      if (content == 'inspire' ||
          (channel.id == Snowflake(836643866358186046) && content == 'i')) {
        final pic = (await http.get(api)).body;
        final embed = EmbedBuilder()..imageUrl = pic;
        final r = await channel.sendMessage(MessageBuilder.embed(embed));
        print('Inspired ${a.username}#${a.discriminator} at ${r.url}: $pic');
      }
    });
}
