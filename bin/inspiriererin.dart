import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:prometheus_client/prometheus_client.dart';
import 'package:prometheus_client/runtime_metrics.dart' as runtime_metrics;
import 'package:prometheus_client_shelf/shelf_handler.dart';
import 'package:shelf/shelf_io.dart';

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

final _client = Client();

Future<Uri> generate() => _client
    .read(Uri(
      scheme: 'https',
      host: 'inspirobot.me',
      path: 'api',
      queryParameters: {'generate': 'true'},
    ))
    .then(Uri.parse);

Future<void> inspire(NyxxGateway b, TextChannel c, String a) async {
  final url = await generate();
  final r = await c.sendMessage(MessageBuilder(content: url.toString()));
  react(String e) => r.react(ReactionBuilder.fromEmoji(b.getTextEmoji(e)));
  await react('⏭').then((_) => react('🔼')).then((_) => react('🔽'));
  print('Inspired $a at <${await r.url}>: $url');
  inspirations.labels([a]).inc();
}

Stream<Message> accumulateMessagesBefore(Message message) async* {
  final msgs =
      message.channel.messages.fetchMany(before: message.id, limit: 100);
  Message? msg;
  for (msg in await msgs) {
    yield msg;
  }
  if (msg != null) {
    yield* accumulateMessagesBefore(msg);
  }
}

Map<String, dynamic> msgToJson(Message m) => {
      'author': '${m.author.username} ${m.author.id.value}',
      'content': m.content,
      'created': m.timestamp.toIso8601String(),
      'edited': m.editedTimestamp?.toIso8601String(),
      'attachments': m.attachments
          .map((a) => {
                'description': a.description,
                'name': a.fileName,
                'url': a.url,
              })
          .toList(),
    };

String msgToText(Message m) =>
    '[${m.editedTimestamp ?? m.timestamp}] ${m.author.username}: ${m.content}'
        .replaceRange(20, 25, '');

void main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('metrics-port', defaultsTo: '8989', help: 'port for prometheus')
    ..addOption('home',
        defaultsTo: '836643866358186046',
        help: 'channel in which `i` is an alias for `inspire`');
  final args = parser.parse(argv);

  final homechannel = Snowflake(int.parse(args['home']));

  final token =
      Platform.environment['INSP_DISCORD_TOKEN'] ?? args.rest.firstOrNull;
  if (token == null || token.isEmpty) {
    stderr.writeln('No token provided (env INSP_DISCORD_TOKEN or pass as arg)');
    exit(1);
  }

  runtime_metrics.register();
  inspirations.register();
  logs.register();
  rateLimits.register();
  serve(prometheusHandler(), InternetAddress.anyIPv6,
          int.parse(args['metrics-port']))
      .then((s) => print(
          'Serving metrics at http://${s.address.host}:${s.port}/metrics'));

  final client = await Nyxx.connectGateway(
      token, GatewayIntents.allUnprivileged | GatewayIntents.messageContent,
      options: GatewayClientOptions(plugins: [Logging(), CliIntegration()]));

  client.httpHandler.onRateLimit.listen((event) {
    print('Rate limited: $event');
  });
  client.onMessageCreate.listen((event) async {
    final msg = event.message;
    final channel = await msg.channel.get() as TextChannel;
    print('Msg from ${msg.author.username}: ${msg.content} <${await msg.url}>');
    final content = msg.content.toLowerCase();
    if (content == 'inspire' || (channel.id == homechannel && content == 'i')) {
      inspire(client, channel, msg.author.username);
    } else if (content.startsWith('\$ log')) {
      final args = content.split(' ');
      final message = args.length < 4
          ? event.message
          : await client.channels
              .get(Snowflake(int.parse(args[2])))
              .then((c) => c as TextChannel)
              .then((c) => c.messages.get(Snowflake(int.parse(args[3]))));
      // TODO: better message
      print('Logging ${message.channel} for ${msg.author.username}...');
      final msgs = await accumulateMessagesBefore(message).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      channel
          .sendMessage(MessageBuilder(attachments: [
            AttachmentBuilder(
                data: utf8.encode(JsonEncoder.withIndent(' ')
                        .convert(msgs.map(msgToJson).toList()) +
                    '\n'),
                fileName: '${channel.id.value}.json'),
            AttachmentBuilder(
                data: utf8.encode(msgs.map(msgToText).join('\n') + '\n'),
                fileName: '${channel.id.value}.txt'),
          ]))
          .then((_) => logs.labels([msg.author.username]).inc());
    }
  });
  client.onMessageReactionAdd.listen((event) async {
    final channel = await event.channel.get() as TextChannel;
    final msg = await event.message.get();
    final author = msg.author;
    final user = await event.user.get();
    if (author.id == client.user.id &&
        user.id != author.id &&
        event.emoji is TextEmoji &&
        (event.emoji as TextEmoji).name == '⏭')
      inspire(client, channel, user.username);
  });
}
