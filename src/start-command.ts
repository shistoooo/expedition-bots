import 'dotenv/config';
import { ExpeditionBot } from './bot';
import { BOT_CONFIGS } from './config';

const bot = new ExpeditionBot(BOT_CONFIGS.command);
bot.start().catch((err) => {
  console.error('[Command] Fatal error:', err);
  process.exit(1);
});
