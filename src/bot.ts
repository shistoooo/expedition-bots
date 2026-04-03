import { Client, GatewayIntentBits, Events, Message, TextChannel, DMChannel, Guild } from 'discord.js';
import http from 'http';
import { BotConfig, GUILD_ID, MOHAMED_USER_ID, AGENT_CHANNELS } from './config';
import { callBrain, BrainInput } from './brain';

function splitMessage(text: string, maxLength = 2000): string[] {
  if (text.length <= maxLength) return [text];
  const chunks: string[] = [];
  let remaining = text;
  while (remaining.length > 0) {
    if (remaining.length <= maxLength) { chunks.push(remaining); break; }
    let si = -1;
    const slice = remaining.slice(0, maxLength);
    si = slice.lastIndexOf('\n\n');
    if (si === -1) si = slice.lastIndexOf('\n');
    if (si === -1) si = slice.lastIndexOf('. ');
    if (si === -1) si = slice.lastIndexOf(' ');
    if (si === -1) si = maxLength - 1;
    const end = si + (slice[si] === '.' ? 2 : 1);
    chunks.push(remaining.slice(0, end));
    remaining = remaining.slice(end).trimStart();
  }
  return chunks;
}

// Detect delegation without actual data in response
const DELEGATION_RE = /(?:transmis|d[ée]l[ée]gu[ée]|demand[ée]|envoy[ée]|consult).*(?:à|a)\s+(Studio|Sales|Wallet|Samus|SamSam)/i;

// Detect if request is complex enough for Deep Think mode
const DEEP_THINK_RE = /rapport complet|bilan|analyse compl[eè]te|r[eé]sum[eé] de tout|compare|crois[eé]|tout.*agent|r[eé]flexion profonde|rapport global/i;

function extractJson(text: string): { tasks: Array<{ agent: string; question: string }> } | null {
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) return null;
  try {
    const parsed = JSON.parse(match[0]);
    if (parsed?.tasks && Array.isArray(parsed.tasks)) return parsed;
    return null;
  } catch { return null; }
}

function detectDelegation(text: string): string | null {
  const match = text.match(DELEGATION_RE);
  if (!match) return null;
  // If the response has real data (long + numbers), it's not a delegation — it's a real answer
  if (text.length > 300 && /\d{2,}/.test(text)) return null;
  return match[1].toLowerCase();
}

export class ExpeditionBot {
  private client: Client;
  private config: BotConfig;
  private token: string;
  private targetChannelId: string | null = null;
  private guild: Guild | null = null;

  constructor(config: BotConfig) {
    this.config = config;
    this.token = process.env[config.tokenEnvVar] || '';
    if (!this.token) throw new Error(`Missing env var: ${config.tokenEnvVar}`);

    this.client = new Client({
      intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent,
        GatewayIntentBits.DirectMessages,
      ],
    });
  }

  // Post in any channel by name
  private async postInChannel(channelName: string, content: string): Promise<void> {
    if (!this.guild) return;
    try {
      const channels = await this.guild.channels.fetch();
      const ch = channels.find(c => c?.name === channelName && c.isTextBased());
      if (ch) {
        for (const chunk of splitMessage(content)) {
          await (ch as TextChannel).send(chunk);
        }
      }
    } catch (err) {
      console.error(`[${this.config.botName}] postInChannel #${channelName} failed:`, err);
    }
  }

  // Reply to a message with split support
  private async replyTo(message: Message, text: string): Promise<void> {
    for (const chunk of splitMessage(text)) {
      await message.reply(chunk);
    }
  }

  // Deep Think mode: decompose → parallel execution → synthesis
  // Only available for Command bot on Railway (no timeout)
  private async handleDeepThink(message: Message, input: BrainInput): Promise<void> {
    const tag = `[${this.config.botName}:DeepThink]`;

    // PHASE 1: PLANIFICATION — ask Command to decompose into subtasks
    console.log(`${tag} Phase 1: Planning...`);
    const planResponse = await callBrain({
      ...input,
      content: `MODE PLANIFICATION. Decompose cette demande en sous-taches JSON.\nReponds UNIQUEMENT: {"tasks":[{"agent":"nom","question":"question precise"}]}\nMax 5 taches. Demande: ${input.content}`,
    });

    const plan = extractJson(planResponse.responseText);
    if (!plan?.tasks?.length) {
      console.log(`${tag} No valid plan — falling back to normal flow`);
      return this.handleTask(message, input);
    }

    console.log(`${tag} Plan: ${plan.tasks.length} tasks → ${plan.tasks.map(t => t.agent).join(', ')}`);
    const agentNames = plan.tasks.map(t => `**${t.agent}**`);
    await this.replyTo(message, `Je lance ${agentNames.join(', ')} en parallele. Standby.`);

    // PHASE 2: PARALLEL EXECUTION — call each agent simultaneously
    console.log(`${tag} Phase 2: Executing ${plan.tasks.length} tasks in parallel...`);
    const results = await Promise.allSettled(
      plan.tasks.map(async (task) => {
        const ch = AGENT_CHANNELS[task.agent] || task.agent;
        // Command posts the question naturally in the agent's channel
        await this.postInChannel(ch, `${task.question}\n\n— *Command*`);

        const r = await callBrain({
          ...input,
          agentId: task.agent,
          content: task.question,
          senderType: 'agent',
          senderId: 'command',
          senderName: 'Command',
        });

        const responseText = r.responseText || 'Pas de reponse';
        if (r.responseText) {
          // Agent responds naturally in their own channel
          await this.postInChannel(ch, r.responseText.slice(0, 1500));
        }
        return { agent: task.agent, response: responseText };
      })
    );

    const fulfilled = results
      .filter((r): r is PromiseFulfilledResult<{ agent: string; response: string }> => r.status === 'fulfilled')
      .map(r => r.value);

    const failed = results.filter(r => r.status === 'rejected').length;
    console.log(`${tag} Phase 2 done: ${fulfilled.length} OK, ${failed} failed`);

    if (fulfilled.length === 0) {
      await this.replyTo(message, '⚠️ Aucun agent n\'a pu repondre. Essaie avec une demande plus simple.');
      return;
    }

    // PHASE 3: SYNTHESIS — Command compiles everything
    console.log(`${tag} Phase 3: Synthesis...`);
    const compiled = fulfilled
      .map(r => `[${r.agent}]: ${r.response}`)
      .join('\n---\n');

    const synthesis = await callBrain({
      ...input,
      content: `MODE SYNTHESE. Compile en reponse executive structuree.\nDemande originale: ${input.content}\n\nResultats des agents:\n${compiled}\n\nAjoute ton analyse strategique et 3 recommandations concretes.`,
    });

    await this.replyTo(message, synthesis.responseText);
    console.log(`${tag} Done — synthesized ${fulfilled.length} agent responses`);
  }

  // The main work method — handles delegation, multi-agent calls, PDFs
  // Runs in the bot process (Railway) — NO TIMEOUT
  private async handleTask(message: Message, input: BrainInput): Promise<void> {
    const tag = `[${this.config.botName}]`;

    // Step 1: Call brain as Command
    console.log(`${tag} Calling brain as ${input.agentId}...`);
    const response = await callBrain(input);

    if (!response.responseText) {
      console.warn(`${tag} Empty brain response`);
      return;
    }

    // Step 2: Check if Command wants to delegate
    const delegateTo = this.config.agentId === 'command' ? detectDelegation(response.responseText) : null;

    if (delegateTo) {
      const targetChannel = AGENT_CHANNELS[delegateTo] || delegateTo;
      console.log(`${tag} Delegation detected → ${delegateTo} in #${targetChannel}`);

      // Show delegation naturally — Command talks like a leader, not a system
      await this.replyTo(message, `Je mets **${delegateTo}** dessus.`);
      await this.postInChannel(targetChannel, `${input.content}\n\n— *demande de Command pour Mohamed*`);

      // Step 3: Call brain as the target agent WITH the original user message
      console.log(`${tag} Calling brain as ${delegateTo}...`);
      try {
        const delegatedResponse = await callBrain({
          ...input,
          agentId: delegateTo,
          content: input.content, // Pass the ORIGINAL user request, not Command's delegation text
          senderType: 'agent',
          senderId: 'command',
          senderName: 'Command',
        });

        if (delegatedResponse.responseText) {
          // Post agent's response naturally in their channel
          await this.postInChannel(targetChannel, delegatedResponse.responseText);

          // Report back to user — Command relays naturally
          await this.replyTo(message, delegatedResponse.responseText);
        } else {
          console.warn(`${tag} Empty response from ${delegateTo}`);
          await this.postInChannel(targetChannel, `⚠️ **${delegateTo}** n'a pas pu traiter la demande (timeout)`);
          await this.replyTo(message, `⚠️ **${delegateTo}** n'a pas pu traiter cette demande — elle est trop complexe pour un seul appel. Essaie de la simplifier (ex: "5 sujets" au lieu de "30").`);
        }
      } catch (delegateErr) {
        console.error(`${tag} Delegation to ${delegateTo} failed:`, delegateErr);
        await this.postInChannel(targetChannel, `❌ Erreur lors de la delegation Command → ${delegateTo}`);
        await this.replyTo(message, `⚠️ **${delegateTo}** n'a pas repondu (timeout). La requete est peut-etre trop lourde — essaie avec moins d'elements.`);
      }
    } else {
      // No delegation — direct response from this agent
      await this.replyTo(message, response.responseText);
    }
  }

  async start(): Promise<void> {
    // --- Ready: store guild + find target channel ---
    this.client.once(Events.ClientReady, async (c) => {
      console.log(`[${this.config.botName}] Connected as ${c.user.tag}`);
      try {
        this.guild = await c.guilds.fetch(GUILD_ID);
        const channels = await this.guild.channels.fetch();
        const match = channels.find(ch => ch?.name === this.config.channelName && ch.isTextBased());
        if (match) {
          this.targetChannelId = match.id;
          console.log(`[${this.config.botName}] Listening on #${this.config.channelName} (${match.id})`);
        } else {
          console.warn(`[${this.config.botName}] Channel #${this.config.channelName} not found`);
        }
      } catch (err) {
        console.error(`[${this.config.botName}] Guild fetch failed:`, err);
      }
    });

    // --- Message handler ---
    this.client.on(Events.MessageCreate, async (message: Message) => {
      if (message.author.bot) return;

      const isDM = !message.guild;
      const isTargetChannel = message.channel.id === this.targetChannelId;
      if (!isDM && !isTargetChannel) return;
      if (isDM && message.author.id !== MOHAMED_USER_ID) return;

      console.log(`[${this.config.botName}] ${message.author.username}: "${message.content.slice(0, 60)}"`);

      const input: BrainInput = {
        agentId: this.config.agentId,
        userId: MOHAMED_USER_ID,
        content: message.content,
        sourceChannel: isDM ? 'discord_dm' : 'discord_channel',
        sourceChannelId: isDM ? undefined : message.channel.id,
        senderId: message.author.id,
        senderName: message.author.displayName || message.author.username,
        senderType: 'user',
      };

      // ALL tasks go through handleTask (background, no timeout)
      // For simple tasks it's fast (~10s), for complex ones it takes longer
      // Either way, Railway has no timeout — it just works

      const channel = message.channel as TextChannel | DMChannel;

      // Show typing while working
      await channel.sendTyping();
      const typingInterval = setInterval(() => {
        channel.sendTyping().catch(() => {});
      }, 8_000);

      try {
        // Deep Think for complex multi-agent requests (Command only)
        if (this.config.agentId === 'command' && DEEP_THINK_RE.test(input.content)) {
          await this.handleDeepThink(message, input);
        } else {
          await this.handleTask(message, input);
        }
      } catch (err) {
        console.error(`[${this.config.botName}] Task failed:`, err);
        try {
          await message.reply('Erreur de traitement. Reessaie.');
        } catch { /* ignore */ }
      } finally {
        clearInterval(typingInterval);
      }
    });

    // --- Login ---
    await this.client.login(this.token);

    // --- Health check ---
    const port = process.env.PORT || 3000;
    const startTime = Date.now();
    http.createServer((_req, res) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok', bot: this.config.botName.toLowerCase(), uptime: Math.floor((Date.now() - startTime) / 1000) }));
    }).listen(port, () => {
      console.log(`[${this.config.botName}] Health check on port ${port}`);
    }).on('error', (err: Error) => {
      console.error(`[${this.config.botName}] HTTP error:`, err.message);
    });
  }
}
