import 'dotenv/config';
import { ExpeditionBot } from './bot';
import { BOT_CONFIGS } from './config';

const bot = new ExpeditionBot(BOT_CONFIGS.sales);
bot.start().catch((err) => {
  console.error('[Sales] Fatal error:', err);
  process.exit(1);
});
