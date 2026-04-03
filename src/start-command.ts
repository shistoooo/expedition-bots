import 'dotenv/config';
import { ExpeditionBot } from './bot';
import { BOT_CONFIGS } from './config';

console.log('[Command] Boot — token:', !!process.env.DISCORD_TOKEN_COMMAND);

const bot = new ExpeditionBot(BOT_CONFIGS.command);
bot.start()
  .then(() => console.log('[Command] Started'))
  .catch((err) => {
    console.error('[Command] Fatal:', err);
    process.exit(1);
  });
