// Client HTTP pour l'API agent-brain de MeLifeOS

export interface BrainInput {
  agentId: string;
  userId: string;
  content: string;
  sourceChannel: 'discord_dm' | 'discord_channel';
  sourceChannelId?: string;
  senderId: string;
  senderName: string;
  senderType?: 'user' | 'agent' | 'participant' | 'system';
  conversationId?: string;
  missionId?: string;
}

export interface BrainResponse {
  responseText: string;
  conversationId?: string;
  missionId?: string | null;
  proposedActions?: Array<{
    actionType: string;
    targetId?: string;
    content: string;
    requiresApproval: boolean;
  }>;
}

const BRAIN_URL = process.env.BRAIN_URL || 'https://melifeos.vercel.app/api/agent-brain';
const AGENT_BRAIN_SECRET = process.env.AGENT_BRAIN_SECRET || '';

export async function callBrain(input: BrainInput): Promise<BrainResponse> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30_000);

  try {
    const res = await fetch(BRAIN_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${AGENT_BRAIN_SECRET}`,
      },
      body: JSON.stringify(input),
      signal: controller.signal,
    });

    if (!res.ok) {
      // Retry once on 5xx
      if (res.status >= 500) {
        console.warn(`[brain] 5xx (${res.status}), retrying once...`);
        const retry = await fetch(BRAIN_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${AGENT_BRAIN_SECRET}`,
          },
          body: JSON.stringify(input),
        });
        if (!retry.ok) {
          const text = await retry.text();
          throw new Error(`Brain API error ${retry.status}: ${text}`);
        }
        return await retry.json() as BrainResponse;
      }
      const text = await res.text();
      throw new Error(`Brain API error ${res.status}: ${text}`);
    }

    return await res.json() as BrainResponse;
  } finally {
    clearTimeout(timeout);
  }
}
