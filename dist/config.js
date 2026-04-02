"use strict";
// Configuration des 4 bots Expedition HQ
Object.defineProperty(exports, "__esModule", { value: true });
exports.AGENT_CHANNELS = exports.MOHAMED_USER_ID = exports.GUILD_ID = exports.BOT_CONFIGS = void 0;
exports.BOT_CONFIGS = {
    command: {
        botName: 'Command',
        agentId: 'command',
        channelName: 'briefing',
        tokenEnvVar: 'DISCORD_TOKEN_COMMAND',
    },
    wallet: {
        botName: 'Wallet',
        agentId: 'wallet',
        channelName: 'wallet',
        tokenEnvVar: 'DISCORD_TOKEN_WALLET',
    },
    studio: {
        botName: 'Studio',
        agentId: 'studio',
        channelName: 'youtube',
        tokenEnvVar: 'DISCORD_TOKEN_STUDIO',
    },
    sales: {
        botName: 'Sales',
        agentId: 'sales',
        channelName: 'sales',
        tokenEnvVar: 'DISCORD_TOKEN_SALES',
    },
};
exports.GUILD_ID = process.env.EXPEDITION_HQ_GUILD_ID || '1488262277009379341';
exports.MOHAMED_USER_ID = process.env.DISCORD_MOHAMED_USER_ID || '1455949646705987702';
// Mapping agent name → Discord channel name (for cross-agent posting)
exports.AGENT_CHANNELS = {
    studio: 'youtube',
    sales: 'sales',
    wallet: 'wallet',
    samus: 'général',
    samsam: 'support',
    command: 'briefing',
};
