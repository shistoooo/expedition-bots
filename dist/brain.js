"use strict";
// Client HTTP pour l'API agent-brain de MeLifeOS
Object.defineProperty(exports, "__esModule", { value: true });
exports.callBrain = callBrain;
const BRAIN_URL = process.env.BRAIN_URL || 'https://melifeos.vercel.app/api/agent-brain';
const AGENT_BRAIN_SECRET = process.env.AGENT_BRAIN_SECRET || '';
async function callBrain(input) {
    const controller = new AbortController();
    // 65s: higher than Vercel's 60s hard kill so we receive the time-guard partial response
    const timeout = setTimeout(() => controller.abort(), 65_000);
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
                return await retry.json();
            }
            const text = await res.text();
            throw new Error(`Brain API error ${res.status}: ${text}`);
        }
        return await res.json();
    }
    finally {
        clearTimeout(timeout);
    }
}
