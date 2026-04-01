import { Client, GatewayIntentBits, Events, Message, TextChannel, DMChannel } from 'discord.js';
import http from 'http';
import { BotConfig, GUILD_ID, MOHAMED_USER_ID } from './config';
import { callBrain, BrainInput } from './brain';

/**
 * Splits a long message into chunks that fit Discord's 2000-char limit.
 * Prefers splitting at paragraph breaks, then newlines, then sentences.
 */
function splitMessage(text: string, maxLength = 2000): string[] {
  if (text.length <= maxLength) return [text];

  const chunks: string[] = [];
  let remaining = text;

  while (remaining.length > 0) {
    if (remaining.length <= maxLength) {
      chunks.push(remaining);
      break;
    }

    let splitIndex = -1;
    const slice = remaining.slice(0, maxLength);

    // Try splitting at paragraph break
    splitIndex = slice.lastIndexOf('\n\n');
    if (splitIndex === -1) splitIndex = slice.lastIndexOf('\n');
    if (splitIndex === -1) splitIndex = slice.lastIndexOf('. ');
    if (splitIndex === -1) splitIndex = slice.lastIndexOf(' ');
    if (splitIndex === -1) splitIndex = maxLength - 1;

    // Include the delimiter in the chunk
    const chunkEnd = splitIndex + (slice[splitIndex] === '.' ? 2 : 1);
    chunks.push(remaining.slice(0, chunkEnd));
    remaining = remaining.slice(chunkEnd).trimStart();
  }

  return chunks;
}

export class ExpeditionBot {
  private client: Client;
  private config: BotConfig;
  private token: string;
  private targetChannelId: string | null = null;

  constructor(config: BotConfig) {
    this.config = config;
    this.token = process.env[config.tokenEnvVar] || '';

    if (!this.token) {
      throw new Error(`Missing env var: ${config.tokenEnvVar}`);
    }

    this.client = new Client({
      intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent,
        GatewayIntentBits.DirectMessages,
      ],
    });
  }

  async start(): Promise<void> {
    // --- Ready event: find target channel ---
    this.client.once(Events.ClientReady, async (c) => {
      console.log(`[${this.config.botName}] Connected as ${c.user.tag}`);

      try {
        const guild = await c.guilds.fetch(GUILD_ID);
        const channels = await guild.channels.fetch();

        const match = channels.find(
          (ch) => ch?.name === this.config.channelName && ch.isTextBased()
        );

        if (match) {
          this.targetChannelId = match.id;
          console.log(`[${this.config.botName}] Listening on #${this.config.channelName} (${match.id})`);
        } else {
          console.warn(`[${this.config.botName}] Channel #${this.config.channelName} not found in guild ${GUILD_ID}`);
        }
      } catch (err) {
        console.error(`[${this.config.botName}] Failed to fetch guild channels:`, err);
      }
    });

    // --- Message handler ---
    this.client.on(Events.MessageCreate, async (message: Message) => {
      // Ignore bots
      if (message.author.bot) return;

      const isDM = !message.guild;
      const isTargetChannel = message.channel.id === this.targetChannelId;

      // Only respond in target channel or DMs from Mohamed
      if (!isDM && !isTargetChannel) return;
      if (isDM && message.author.id !== MOHAMED_USER_ID) return;

      // Build brain input
      const input: BrainInput = {
        agentId: this.config.agentId,
        userId: MOHAMED_USER_ID,
        content: message.content,
        sourceChannel: isDM ? 'discord_dm' : 'discord_channel',
        sourceChannelId: isDM ? undefined : message.channel.id,
        senderId: message.author.id,
        senderName: message.author.displayName || message.author.username,
        senderType: 'user',
      };

      const channel = message.channel as TextChannel | DMChannel;
      let typingInterval: ReturnType<typeof setInterval> | null = null;

      try {
        // Show typing indicator
        await channel.sendTyping();

        // Keep typing alive during brain call (typing expires after 10s)
        typingInterval = setInterval(() => {
          channel.sendTyping().catch(() => {});
        }, 8_000);

        const response = await callBrain(input);

        if (!response.responseText) {
          console.warn(`[${this.config.botName}] Empty response from brain`);
          return;
        }

        // Send response (split if needed)
        const chunks = splitMessage(response.responseText);
        for (const chunk of chunks) {
          await message.reply(chunk);
        }
      } catch (err) {
        console.error(`[${this.config.botName}] Error handling message:`, err);
        try {
          await message.reply(`Erreur de traitement. Reessaie dans quelques secondes.`);
        } catch { /* ignore reply error */ }
      } finally {
        if (typingInterval) clearInterval(typingInterval);
      }
    });

    // --- Login ---
    await this.client.login(this.token);

    // --- Health check HTTP server ---
    const port = process.env.PORT || 3000;
    const startTime = Date.now();

    http.createServer((_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        status: 'ok',
        bot: this.config.botName.toLowerCase(),
        uptime: Math.floor((Date.now() - startTime) / 1000),
      }));
    }).listen(port, () => {
      console.log(`[${this.config.botName}] Health check on port ${port}`);
    }).on('error', (err: Error) => {
      console.error(`[${this.config.botName}] HTTP listen error:`, err.message);
    });
  }
}
