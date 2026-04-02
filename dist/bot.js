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
        splitIndex = slice.lastIndexOf('\n\n');
        if (splitIndex === -1)
            splitIndex = slice.lastIndexOf('\n');
        if (splitIndex === -1)
            splitIndex = slice.lastIndexOf('. ');
        if (splitIndex === -1)
            splitIndex = slice.lastIndexOf(' ');
        if (splitIndex === -1)
            splitIndex = maxLength - 1;
        const chunkEnd = splitIndex + (slice[splitIndex] === '.' ? 2 : 1);
        chunks.push(remaining.slice(0, chunkEnd));
        remaining = remaining.slice(chunkEnd).trimStart();
    }
    return chunks;
}
// Detect if a response is a delegation without actual data
const DELEGATION_PATTERN = /(?:transmis|d[ée]l[ée]gu[ée]|demand[ée]|envoy[ée]|consult).*(?:à|a)\s+(Studio|Sales|Wallet|Samus|SamSam)/i;
const DATA_INDICATORS = /\d{2,}|\bEUR\b|\bMRR\b|http|\.pdf|graphique|tableau|sujet|titre|vid[ée]o/i;
function isDelegationWithoutData(text) {
    const match = text.match(DELEGATION_PATTERN);
    if (!match)
        return { isDelegation: false, targetAgent: '' };
    // If the response is short AND mentions delegation → it's a delegation without data
    const hasData = DATA_INDICATORS.test(text) && text.length > 200;
    return { isDelegation: !hasData, targetAgent: match[1].toLowerCase() };
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
    // Post a message in any channel by name
    async postInChannel(channelName, content) {
        if (!this.guild)
            return;
        try {
            const channels = await this.guild.channels.fetch();
            const ch = channels.find(c => c?.name === channelName && c.isTextBased());
            if (ch) {
                const chunks = splitMessage(content);
                for (const chunk of chunks) {
                    await ch.send(chunk);
                }
            }
            else {
                console.warn(`[${this.config.botName}] Channel #${channelName} not found`);
            }
        }
        catch (err) {
            console.error(`[${this.config.botName}] Failed to post in #${channelName}:`, err);
        }
    }
    // Execute a mission asynchronously (no timeout — Railway process is persistent)
    async executeMission(message, input) {
        const tag = `[${this.config.botName}]`;
        try {
            console.log(`${tag} Mission started: "${input.content.slice(0, 80)}..."`);
            // Step 1: Call brain (Command)
            const response = await (0, brain_1.callBrain)(input);
            if (!response.responseText) {
                await message.reply('Mission terminee — aucune reponse.');
                return;
            }
            // Step 2: Check if Command delegated
            const { isDelegation, targetAgent } = isDelegationWithoutData(response.responseText);
            if (isDelegation && targetAgent) {
                const targetChannel = config_1.AGENT_CHANNELS[targetAgent] || targetAgent;
                console.log(`${tag} Mission delegation: ${targetAgent} in #${targetChannel}`);
                // Post in target agent's channel
                await this.postInChannel(targetChannel, `📩 **[Command → ${targetAgent}]**\n${input.content}`);
                // Update user
                await message.reply(`⏳ ${targetAgent} travaille dessus...`);
                // Call brain as target agent
                const delegatedResponse = await (0, brain_1.callBrain)({
                    ...input,
                    agentId: targetAgent,
                    senderType: 'agent',
                    senderId: 'command',
                    senderName: 'Command',
                });
                // Post agent's response in their channel
                if (delegatedResponse.responseText) {
                    await this.postInChannel(targetChannel, delegatedResponse.responseText);
                    // Report back to user in original channel
                    const report = `📋 **Reponse de ${targetAgent}:**\n${delegatedResponse.responseText}`;
                    const chunks = splitMessage(report);
                    for (const chunk of chunks) {
                        await message.reply(chunk);
                    }
                }
            }
            else {
                // Direct response from Command (no delegation)
                const chunks = splitMessage(response.responseText);
                for (const chunk of chunks) {
                    await message.reply(chunk);
                }
            }
            console.log(`${tag} Mission complete`);
        }
        catch (err) {
            console.error(`${tag} Mission failed:`, err);
            try {
                await message.reply('❌ Mission echouee. Reessaie.');
            }
            catch { /* ignore */ }
        }
    }
    async start() {
        // --- Ready event: find target channel + store guild ---
        this.client.once(discord_js_1.Events.ClientReady, async (c) => {
            console.log(`[${this.config.botName}] Connected as ${c.user.tag}`);
            try {
                this.guild = await c.guilds.fetch(config_1.GUILD_ID);
                const channels = await this.guild.channels.fetch();
                const match = channels.find((ch) => ch?.name === this.config.channelName && ch.isTextBased());
                if (match) {
                    this.targetChannelId = match.id;
                    console.log(`[${this.config.botName}] Listening on #${this.config.channelName} (${match.id})`);
                }
                else {
                    console.warn(`[${this.config.botName}] Channel #${this.config.channelName} not found`);
                }
            }
            catch (err) {
                console.error(`[${this.config.botName}] Failed to fetch guild:`, err);
            }
        });
        // --- Message handler ---
        this.client.on(discord_js_1.Events.MessageCreate, async (message) => {
            // Ignore bots (prevents loops)
            if (message.author.bot)
                return;
            const isDM = !message.guild;
            const isTargetChannel = message.channel.id === this.targetChannelId;
            // Only respond in target channel or DMs from Mohamed
            if (!isDM && !isTargetChannel)
                return;
            if (isDM && message.author.id !== config_1.MOHAMED_USER_ID)
                return;
            console.log(`[${this.config.botName}] Message from ${message.author.username}: "${message.content.slice(0, 60)}"`);
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
            // Detect complex tasks → run as background mission (no timeout)
            const isComplex = /pdf|rapport|document|analyse|genere|mission|complet/i.test(input.content);
            if (isComplex && this.config.agentId === 'command') {
                // Respond immediately, work in background
                await message.reply('⏳ Mission reçue. Je travaille dessus...');
                // Fire and forget — no timeout on Railway
                this.executeMission(message, input).catch(err => {
                    console.error(`[${this.config.botName}] Background mission error:`, err);
                });
                return;
            }
            // Normal flow — direct response with typing indicator
            const channel = message.channel;
            let typingInterval = null;
            try {
                await channel.sendTyping();
                typingInterval = setInterval(() => {
                    channel.sendTyping().catch(() => { });
                }, 8_000);
                const response = await (0, brain_1.callBrain)(input);
                if (!response.responseText) {
                    console.warn(`[${this.config.botName}] Empty response from brain`);
                    return;
                }
                // Check for delegation (only Command bot does this)
                if (this.config.agentId === 'command') {
                    const { isDelegation, targetAgent } = isDelegationWithoutData(response.responseText);
                    if (isDelegation && targetAgent) {
                        // Clear typing — we're going to do async work
                        if (typingInterval) {
                            clearInterval(typingInterval);
                            typingInterval = null;
                        }
                        const targetChannel = config_1.AGENT_CHANNELS[targetAgent] || targetAgent;
                        console.log(`[${this.config.botName}] Delegating to ${targetAgent} in #${targetChannel}`);
                        // Notify user
                        await message.reply(`⏳ Je consulte ${targetAgent}...`);
                        // Post in agent's channel
                        await this.postInChannel(targetChannel, `📩 **[Command → ${targetAgent}]**\n${input.content}`);
                        // Call brain as the target agent
                        const delegatedResponse = await (0, brain_1.callBrain)({
                            ...input,
                            agentId: targetAgent,
                            senderType: 'agent',
                            senderId: 'command',
                            senderName: 'Command',
                        });
                        // Post response in agent's channel
                        if (delegatedResponse.responseText) {
                            await this.postInChannel(targetChannel, delegatedResponse.responseText);
                            // Report back in #briefing
                            const report = `📋 **Reponse de ${targetAgent}:**\n${delegatedResponse.responseText}`;
                            const chunks = splitMessage(report);
                            for (const chunk of chunks) {
                                await message.reply(chunk);
                            }
                        }
                        else {
                            await message.reply(`${targetAgent} n'a pas repondu.`);
                        }
                        return;
                    }
                }
                // Standard response (no delegation)
                const chunks = splitMessage(response.responseText);
                for (const chunk of chunks) {
                    await message.reply(chunk);
                }
            }
            catch (err) {
                console.error(`[${this.config.botName}] Error:`, err);
                try {
                    await message.reply('Erreur de traitement. Reessaie dans quelques secondes.');
                }
                catch { /* ignore */ }
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
