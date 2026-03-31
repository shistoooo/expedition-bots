// Configuration des 4 bots Expedition HQ

export interface BotConfig {
  botName: string;
  agentId: string;
  channelName: string;
  tokenEnvVar: string;
}

export const BOT_CONFIGS: Record<string, BotConfig> = {
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

export const GUILD_ID = process.env.EXPEDITION_HQ_GUILD_ID || '1488262277009379341';
export const MOHAMED_USER_ID = process.env.DISCORD_MOHAMED_USER_ID || '1455949646705987702';
