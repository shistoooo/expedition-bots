"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
require("dotenv/config");
const bot_1 = require("./bot");
const config_1 = require("./config");
const bot = new bot_1.ExpeditionBot(config_1.BOT_CONFIGS.command);
bot.start().catch((err) => {
    console.error('[Command] Fatal error:', err);
    process.exit(1);
});
