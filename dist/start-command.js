"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
require("dotenv/config");
const bot_1 = require("./bot");
const config_1 = require("./config");
console.log('[Command] Boot — token:', !!process.env.DISCORD_TOKEN_COMMAND);
const bot = new bot_1.ExpeditionBot(config_1.BOT_CONFIGS.command);
bot.start()
    .then(() => console.log('[Command] Started'))
    .catch((err) => {
    console.error('[Command] Fatal:', err);
    process.exit(1);
});
