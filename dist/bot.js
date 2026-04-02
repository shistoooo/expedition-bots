"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ExpeditionBot = void 0;
const discord_js_1 = require("discord.js");
const http_1 = __importDefault(require("http"));
const config_1 = require("./config");
const brain_1 = require("./brain");
/**
 * Splits a long message into chunks that fit Discord's 2000-char limit.
 * Prefers splitting at paragraph breaks, then newlines, then sentences.
 */
function splitMessage(text, maxLength = 2000) {
    if (text.length <= maxLength)
        return [text];
    const chunks = [];
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
        if (splitIndex === -1)
            splitIndex = slice.lastIndexOf('\n');
        if (splitIndex === -1)
            splitIndex = slice.lastIndexOf('. ');
        if (splitIndex === -1)
            splitIndex = slice.lastIndexOf(' ');
        if (splitIndex === -1)
            splitIndex = maxLength - 1;
        // Include the delimiter in the chunk
        const chunkEnd = splitIndex + (slice[splitIndex] === '.' ? 2 : 1);
        chunks.push(remaining.slice(0, chunkEnd));
        remaining = remaining.slice(chunkEnd).trimStart();
    }
    return chunks;
}
class ExpeditionBot {
    client;
    config;
    token;
    targetChannelId = null;
    constructor(config) {
        this.config = config;
        this.token = process.env[config.tokenEnvVar] || '';
        if (!this.token) {
            throw new Error(`Missing env var: ${config.tokenEnvVar}`);
        }
        this.client = new discord_js_1.Client({
            intents: [
                discord_js_1.GatewayIntentBits.Guilds,
                discord_js_1.GatewayIntentBits.GuildMessages,
                discord_js_1.GatewayIntentBits.MessageContent,
                discord_js_1.GatewayIntentBits.DirectMessages,
            ],
        });
    }
    async start() {
        // --- Ready event: find target channel ---
        this.client.once(discord_js_1.Events.ClientReady, async (c) => {
            console.log(`[${this.config.botName}] Connected as ${c.user.tag}`);
            try {
                const guild = await c.guilds.fetch(config_1.GUILD_ID);
                const channels = await guild.channels.fetch();
                const match = channels.find((ch) => ch?.name === this.config.channelName && ch.isTextBased());
                if (match) {
                    this.targetChannelId = match.id;
                    console.log(`[${this.config.botName}] Listening on #${this.config.channelName} (${match.id})`);
                }
                else {
                    console.warn(`[${this.config.botName}] Channel #${this.config.channelName} not found in guild ${config_1.GUILD_ID}`);
                }
            }
            catch (err) {
                console.error(`[${this.config.botName}] Failed to fetch guild channels:`, err);
            }
        });
        // --- Message handler ---
        this.client.on(discord_js_1.Events.MessageCreate, async (message) => {
            // Ignore bots
            if (message.author.bot)
                return;
            const isDM = !message.guild;
            const isTargetChannel = message.channel.id === this.targetChannelId;
            // Debug log for message routing
            if (!isDM) {
                console.log(`[${this.config.botName}] Message in #${message.channel.name} (${message.channel.id}) from ${message.author.username}: "${message.content.slice(0, 50)}..." | target=${this.targetChannelId} | match=${isTargetChannel}`);
            }
            // Only respond in target channel or DMs from Mohamed
            if (!isDM && !isTargetChannel)
                return;
            if (isDM && message.author.id !== config_1.MOHAMED_USER_ID)
                return;
            console.log(`[${this.config.botName}] Processing message from ${message.author.username}`);
            // Build brain input
            const input = {
                agentId: this.config.agentId,
                userId: config_1.MOHAMED_USER_ID,
                content: message.content,
                sourceChannel: isDM ? 'discord_dm' : 'discord_channel',
                sourceChannelId: isDM ? undefined : message.channel.id,
                senderId: message.author.id,
                senderName: message.author.displayName || message.author.username,
                senderType: 'user',
            };
            const channel = message.channel;
            let typingInterval = null;
            try {
                // Show typing indicator
                await channel.sendTyping();
                // Keep typing alive during brain call (typing expires after 10s)
                typingInterval = setInterval(() => {
                    channel.sendTyping().catch(() => { });
                }, 8_000);
                const response = await (0, brain_1.callBrain)(input);
                if (!response.responseText) {
                    console.warn(`[${this.config.botName}] Empty response from brain`);
                    return;
                }
                // Send response (split if needed)
                const chunks = splitMessage(response.responseText);
                for (const chunk of chunks) {
                    await message.reply(chunk);
                }
            }
            catch (err) {
                console.error(`[${this.config.botName}] Error handling message:`, err);
                try {
                    await message.reply(`Erreur de traitement. Reessaie dans quelques secondes.`);
                }
                catch { /* ignore reply error */ }
            }
            finally {
                if (typingInterval)
                    clearInterval(typingInterval);
            }
        });
        // --- Login ---
        await this.client.login(this.token);
        // --- Health check HTTP server ---
        const port = process.env.PORT || 3000;
        const startTime = Date.now();
        http_1.default.createServer((_req, res) => {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({
                status: 'ok',
                bot: this.config.botName.toLowerCase(),
                uptime: Math.floor((Date.now() - startTime) / 1000),
            }));
        }).listen(port, () => {
            console.log(`[${this.config.botName}] Health check on port ${port}`);
        }).on('error', (err) => {
            console.error(`[${this.config.botName}] HTTP listen error:`, err.message);
        });
    }
}
exports.ExpeditionBot = ExpeditionBot;
