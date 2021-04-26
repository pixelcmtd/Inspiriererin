import 'package:http/http.dart' as http;
import 'package:nyxx/nyxx.dart';

final api = Uri.parse('https://inspirobot.me/api?generate=true');

void main(List<String> argv) {
  Nyxx(argv.first, GatewayIntents.allUnprivileged,
      options: ClientOptions(guildSubscriptions: false))
    ..onMessageReceived.listen((event) async {
      final msg = event.message;
      final channel = await msg.channel.getOrDownload();
      if (msg.content == 'inspire') {
        final picUrl = (await http.get(api)).body;
        print('Inspiring: $picUrl');
        await channel.sendMessage(content: picUrl);
      }
    });
}
