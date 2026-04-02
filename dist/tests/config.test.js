"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const vitest_1 = require("vitest");
const config_1 = require("../config");
(0, vitest_1.describe)('BOT_CONFIGS', () => {
    const expectedBots = ['command', 'wallet', 'studio', 'sales'];
    (0, vitest_1.it)('contient les 4 bots', () => {
        (0, vitest_1.expect)(Object.keys(config_1.BOT_CONFIGS)).toEqual(expectedBots);
    });
    (0, vitest_1.it)('chaque bot a un agentId unique', () => {
        const agentIds = Object.values(config_1.BOT_CONFIGS).map(c => c.agentId);
        (0, vitest_1.expect)(new Set(agentIds).size).toBe(4);
    });
    (0, vitest_1.it)('chaque bot a un channelName unique', () => {
        const channels = Object.values(config_1.BOT_CONFIGS).map(c => c.channelName);
        (0, vitest_1.expect)(new Set(channels).size).toBe(4);
    });
    (0, vitest_1.it)('chaque bot a un tokenEnvVar unique', () => {
        const tokens = Object.values(config_1.BOT_CONFIGS).map(c => c.tokenEnvVar);
        (0, vitest_1.expect)(new Set(tokens).size).toBe(4);
    });
    (0, vitest_1.it)('command bot pointe sur le channel briefing', () => {
        (0, vitest_1.expect)(config_1.BOT_CONFIGS.command.channelName).toBe('briefing');
        (0, vitest_1.expect)(config_1.BOT_CONFIGS.command.agentId).toBe('command');
        (0, vitest_1.expect)(config_1.BOT_CONFIGS.command.tokenEnvVar).toBe('DISCORD_TOKEN_COMMAND');
    });
    (0, vitest_1.it)('wallet bot pointe sur le channel wallet', () => {
        (0, vitest_1.expect)(config_1.BOT_CONFIGS.wallet.channelName).toBe('wallet');
        (0, vitest_1.expect)(config_1.BOT_CONFIGS.wallet.agentId).toBe('wallet');
    });
    (0, vitest_1.it)('studio bot pointe sur le channel youtube', () => {
        (0, vitest_1.expect)(config_1.BOT_CONFIGS.studio.channelName).toBe('youtube');
        (0, vitest_1.expect)(config_1.BOT_CONFIGS.studio.agentId).toBe('studio');
    });
    (0, vitest_1.it)('sales bot pointe sur le channel sales', () => {
        (0, vitest_1.expect)(config_1.BOT_CONFIGS.sales.channelName).toBe('sales');
        (0, vitest_1.expect)(config_1.BOT_CONFIGS.sales.agentId).toBe('sales');
    });
    (0, vitest_1.it)('tokenEnvVar suit le format DISCORD_TOKEN_{BOT}', () => {
        for (const [key, cfg] of Object.entries(config_1.BOT_CONFIGS)) {
            (0, vitest_1.expect)(cfg.tokenEnvVar).toBe(`DISCORD_TOKEN_${key.toUpperCase()}`);
        }
    });
});
(0, vitest_1.describe)('Constants', () => {
    (0, vitest_1.it)('GUILD_ID est défini', () => {
        (0, vitest_1.expect)(config_1.GUILD_ID).toBeTruthy();
        (0, vitest_1.expect)(typeof config_1.GUILD_ID).toBe('string');
    });
    (0, vitest_1.it)('MOHAMED_USER_ID est défini', () => {
        (0, vitest_1.expect)(config_1.MOHAMED_USER_ID).toBeTruthy();
        (0, vitest_1.expect)(typeof config_1.MOHAMED_USER_ID).toBe('string');
    });
});
