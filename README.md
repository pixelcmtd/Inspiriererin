# Inspiriererin

A Discord bot that sends you inspirational quotes from Inspirobot.

Installing from Pub is deprecated and will be broken in the future.
The following docker setup is recommended:

```sh
docker run -d --restart=unless-stopped --pull=always --name insp8n -p8989:8989 -e INSP_DISCORD_TOKEN=XXX chrissx/inspiriererin:latest --home 123456789
```
