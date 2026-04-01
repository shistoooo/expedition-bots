import { describe, it, expect } from 'vitest';
import { BOT_CONFIGS, GUILD_ID, MOHAMED_USER_ID } from '../config';

describe('BOT_CONFIGS', () => {
  const expectedBots = ['command', 'wallet', 'studio', 'sales'];

  it('contient les 4 bots', () => {
    expect(Object.keys(BOT_CONFIGS)).toEqual(expectedBots);
  });

  it('chaque bot a un agentId unique', () => {
    const agentIds = Object.values(BOT_CONFIGS).map(c => c.agentId);
    expect(new Set(agentIds).size).toBe(4);
  });

  it('chaque bot a un channelName unique', () => {
    const channels = Object.values(BOT_CONFIGS).map(c => c.channelName);
    expect(new Set(channels).size).toBe(4);
  });

  it('chaque bot a un tokenEnvVar unique', () => {
    const tokens = Object.values(BOT_CONFIGS).map(c => c.tokenEnvVar);
    expect(new Set(tokens).size).toBe(4);
  });

  it('command bot pointe sur le channel briefing', () => {
    expect(BOT_CONFIGS.command.channelName).toBe('briefing');
    expect(BOT_CONFIGS.command.agentId).toBe('command');
    expect(BOT_CONFIGS.command.tokenEnvVar).toBe('DISCORD_TOKEN_COMMAND');
  });

  it('wallet bot pointe sur le channel wallet', () => {
    expect(BOT_CONFIGS.wallet.channelName).toBe('wallet');
    expect(BOT_CONFIGS.wallet.agentId).toBe('wallet');
  });

  it('studio bot pointe sur le channel youtube', () => {
    expect(BOT_CONFIGS.studio.channelName).toBe('youtube');
    expect(BOT_CONFIGS.studio.agentId).toBe('studio');
  });

  it('sales bot pointe sur le channel sales', () => {
    expect(BOT_CONFIGS.sales.channelName).toBe('sales');
    expect(BOT_CONFIGS.sales.agentId).toBe('sales');
  });

  it('tokenEnvVar suit le format DISCORD_TOKEN_{BOT}', () => {
    for (const [key, cfg] of Object.entries(BOT_CONFIGS)) {
      expect(cfg.tokenEnvVar).toBe(`DISCORD_TOKEN_${key.toUpperCase()}`);
    }
  });
});

describe('Constants', () => {
  it('GUILD_ID est défini', () => {
    expect(GUILD_ID).toBeTruthy();
    expect(typeof GUILD_ID).toBe('string');
  });

  it('MOHAMED_USER_ID est défini', () => {
    expect(MOHAMED_USER_ID).toBeTruthy();
    expect(typeof MOHAMED_USER_ID).toBe('string');
  });
});
