import 'dotenv/config';
import { ExpeditionBot } from './bot';
import { BOT_CONFIGS } from './config';

const bot = new ExpeditionBot(BOT_CONFIGS.wallet);
bot.start().catch((err) => {
  console.error('[Wallet] Fatal error:', err);
  process.exit(1);
});
