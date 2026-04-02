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
        let si = -1;
        const slice = remaining.slice(0, maxLength);
        si = slice.lastIndexOf('\n\n');
        if (si === -1)
            si = slice.lastIndexOf('\n');
        if (si === -1)
            si = slice.lastIndexOf('. ');
        if (si === -1)
            si = slice.lastIndexOf(' ');
        if (si === -1)
            si = maxLength - 1;
        const end = si + (slice[si] === '.' ? 2 : 1);
        chunks.push(remaining.slice(0, end));
        remaining = remaining.slice(end).trimStart();
    }
    return chunks;
}
// Detect delegation without actual data in response
const DELEGATION_RE = /(?:transmis|d[ée]l[ée]gu[ée]|demand[ée]|envoy[ée]|consult).*(?:à|a)\s+(Studio|Sales|Wallet|Samus|SamSam)/i;
function detectDelegation(text) {
    const match = text.match(DELEGATION_RE);
    if (!match)
        return null;
    // If the response has real data (long + numbers), it's not a delegation — it's a real answer
    if (text.length > 300 && /\d{2,}/.test(text))
        return null;
    return match[1].toLowerCase();
}
class ExpeditionBot {
    client;
    config;
    token;
    targetChannelId = null;
    guild = null;
    constructor(config) {
        this.config = config;
        this.token = process.env[config.tokenEnvVar] || '';
        if (!this.token)
            throw new Error(`Missing env var: ${config.tokenEnvVar}`);
        this.client = new discord_js_1.Client({
            intents: [
                discord_js_1.GatewayIntentBits.Guilds,
                discord_js_1.GatewayIntentBits.GuildMessages,
                discord_js_1.GatewayIntentBits.MessageContent,
                discord_js_1.GatewayIntentBits.DirectMessages,
            ],
        });
    }
    // Post in any channel by name
    async postInChannel(channelName, content) {
        if (!this.guild)
            return;
        try {
            const channels = await this.guild.channels.fetch();
            const ch = channels.find(c => c?.name === channelName && c.isTextBased());
            if (ch) {
                for (const chunk of splitMessage(content)) {
                    await ch.send(chunk);
                }
            }
        }
        catch (err) {
            console.error(`[${this.config.botName}] postInChannel #${channelName} failed:`, err);
        }
    }
    // Reply to a message with split support
    async replyTo(message, text) {
        for (const chunk of splitMessage(text)) {
            await message.reply(chunk);
        }
    }
    // The main work method — handles delegation, multi-agent calls, PDFs
    // Runs in the bot process (Railway) — NO TIMEOUT
    async handleTask(message, input) {
        const tag = `[${this.config.botName}]`;
        // Step 1: Call brain as Command
        console.log(`${tag} Calling brain as ${input.agentId}...`);
        const response = await (0, brain_1.callBrain)(input);
        if (!response.responseText) {
            console.warn(`${tag} Empty brain response`);
            return;
        }
        // Step 2: Check if Command wants to delegate
        const delegateTo = this.config.agentId === 'command' ? detectDelegation(response.responseText) : null;
        if (delegateTo) {
            const targetChannel = config_1.AGENT_CHANNELS[delegateTo] || delegateTo;
            console.log(`${tag} Delegation detected → ${delegateTo} in #${targetChannel}`);
            // Show delegation in Discord
            await this.replyTo(message, `⏳ Je consulte **${delegateTo}**...`);
            await this.postInChannel(targetChannel, `📩 **[Command → ${delegateTo}]** ${input.content}`);
            // Step 3: Call brain as the target agent WITH the original user message
            console.log(`${tag} Calling brain as ${delegateTo}...`);
            const delegatedResponse = await (0, brain_1.callBrain)({
                ...input,
                agentId: delegateTo,
                content: input.content, // Pass the ORIGINAL user request, not Command's delegation text
                senderType: 'agent',
                senderId: 'command',
                senderName: 'Command',
            });
            if (delegatedResponse.responseText) {
                // Post agent's response in their channel (visible communication)
                await this.postInChannel(targetChannel, `💬 **${delegateTo}:** ${delegatedResponse.responseText}`);
                // Report back to user
                await this.replyTo(message, `📋 **${delegateTo} a repondu :**\n${delegatedResponse.responseText}`);
            }
            else {
                await this.replyTo(message, `${delegateTo} n'a pas pu repondre.`);
            }
        }
        else {
            // No delegation — direct response from this agent
            await this.replyTo(message, response.responseText);
        }
    }
    async start() {
        // --- Ready: store guild + find target channel ---
        this.client.once(discord_js_1.Events.ClientReady, async (c) => {
            console.log(`[${this.config.botName}] Connected as ${c.user.tag}`);
            try {
                this.guild = await c.guilds.fetch(config_1.GUILD_ID);
                const channels = await this.guild.channels.fetch();
                const match = channels.find(ch => ch?.name === this.config.channelName && ch.isTextBased());
                if (match) {
                    this.targetChannelId = match.id;
                    console.log(`[${this.config.botName}] Listening on #${this.config.channelName} (${match.id})`);
                }
                else {
                    console.warn(`[${this.config.botName}] Channel #${this.config.channelName} not found`);
                }
            }
            catch (err) {
                console.error(`[${this.config.botName}] Guild fetch failed:`, err);
            }
        });
        // --- Message handler ---
        this.client.on(discord_js_1.Events.MessageCreate, async (message) => {
            if (message.author.bot)
                return;
            const isDM = !message.guild;
            const isTargetChannel = message.channel.id === this.targetChannelId;
            if (!isDM && !isTargetChannel)
                return;
            if (isDM && message.author.id !== config_1.MOHAMED_USER_ID)
                return;
            console.log(`[${this.config.botName}] ${message.author.username}: "${message.content.slice(0, 60)}"`);
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
            // ALL tasks go through handleTask (background, no timeout)
            // For simple tasks it's fast (~10s), for complex ones it takes longer
            // Either way, Railway has no timeout — it just works
            const channel = message.channel;
            // Show typing while working
            await channel.sendTyping();
            const typingInterval = setInterval(() => {
                channel.sendTyping().catch(() => { });
            }, 8_000);
            try {
                await this.handleTask(message, input);
            }
            catch (err) {
                console.error(`[${this.config.botName}] Task failed:`, err);
                try {
                    await message.reply('Erreur de traitement. Reessaie.');
                }
                catch { /* ignore */ }
            }
            finally {
                clearInterval(typingInterval);
            }
        });
        // --- Login ---
        await this.client.login(this.token);
        // --- Health check ---
        const port = process.env.PORT || 3000;
        const startTime = Date.now();
        http_1.default.createServer((_req, res) => {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ status: 'ok', bot: this.config.botName.toLowerCase(), uptime: Math.floor((Date.now() - startTime) / 1000) }));
        }).listen(port, () => {
            console.log(`[${this.config.botName}] Health check on port ${port}`);
        }).on('error', (err) => {
            console.error(`[${this.config.botName}] HTTP error:`, err.message);
        });
    }
}
exports.ExpeditionBot = ExpeditionBot;
