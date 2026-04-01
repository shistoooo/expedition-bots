import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { callBrain, BrainInput } from '../brain';

const MOCK_INPUT: BrainInput = {
  agentId: 'command',
  userId: '1455949646705987702',
  content: 'quel est le score global ?',
  sourceChannel: 'discord_channel',
  senderId: '1455949646705987702',
  senderName: 'Mohamed',
  senderType: 'user',
};

const MOCK_RESPONSE = {
  responseText: 'Score global : 7/10',
  conversationId: 'conv-123',
};

describe('callBrain', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn());
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('appelle fetch avec les bons headers', async () => {
    vi.mocked(fetch).mockResolvedValueOnce({
      ok: true,
      json: async () => MOCK_RESPONSE,
    } as Response);

    await callBrain(MOCK_INPUT);

    expect(fetch).toHaveBeenCalledOnce();
    const [url, opts] = vi.mocked(fetch).mock.calls[0];
    expect(url).toContain('agent-brain');
    expect((opts as RequestInit).method).toBe('POST');
    expect((opts as RequestInit).headers).toMatchObject({
      'Content-Type': 'application/json',
      'Authorization': expect.stringContaining('Bearer'),
    });
  });

  it('envoie le body JSON correct', async () => {
    vi.mocked(fetch).mockResolvedValueOnce({
      ok: true,
      json: async () => MOCK_RESPONSE,
    } as Response);

    await callBrain(MOCK_INPUT);

    const [, opts] = vi.mocked(fetch).mock.calls[0];
    const body = JSON.parse((opts as RequestInit).body as string);
    expect(body.agentId).toBe('command');
    expect(body.content).toBe('quel est le score global ?');
    expect(body.sourceChannel).toBe('discord_channel');
  });

  it('retourne la réponse du brain', async () => {
    vi.mocked(fetch).mockResolvedValueOnce({
      ok: true,
      json: async () => MOCK_RESPONSE,
    } as Response);

    const result = await callBrain(MOCK_INPUT);
    expect(result.responseText).toBe('Score global : 7/10');
    expect(result.conversationId).toBe('conv-123');
  });

  it('retente une fois sur 5xx', async () => {
    vi.mocked(fetch)
      .mockResolvedValueOnce({ ok: false, status: 503, text: async () => 'Service Unavailable' } as Response)
      .mockResolvedValueOnce({ ok: true, json: async () => MOCK_RESPONSE } as Response);

    const result = await callBrain(MOCK_INPUT);
    expect(fetch).toHaveBeenCalledTimes(2);
    expect(result.responseText).toBe('Score global : 7/10');
  });

  it('throw si la 2ème tentative échoue aussi', async () => {
    vi.mocked(fetch)
      .mockResolvedValueOnce({ ok: false, status: 500, text: async () => 'error' } as Response)
      .mockResolvedValueOnce({ ok: false, status: 500, text: async () => 'error again' } as Response);

    await expect(callBrain(MOCK_INPUT)).rejects.toThrow('Brain API error 500');
  });

  it('throw sur erreur 4xx sans retry', async () => {
    vi.mocked(fetch).mockResolvedValueOnce({
      ok: false,
      status: 401,
      text: async () => 'Unauthorized',
    } as Response);

    await expect(callBrain(MOCK_INPUT)).rejects.toThrow('Brain API error 401');
    expect(fetch).toHaveBeenCalledOnce();
  });

  it('throw sur timeout (AbortError)', async () => {
    vi.mocked(fetch).mockRejectedValueOnce(
      Object.assign(new Error('The operation was aborted'), { name: 'AbortError' })
    );

    await expect(callBrain(MOCK_INPUT)).rejects.toThrow();
  });
});
