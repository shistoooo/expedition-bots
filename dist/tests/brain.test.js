"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const vitest_1 = require("vitest");
const brain_1 = require("../brain");
const MOCK_INPUT = {
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
(0, vitest_1.describe)('callBrain', () => {
    (0, vitest_1.beforeEach)(() => {
        vitest_1.vi.stubGlobal('fetch', vitest_1.vi.fn());
    });
    (0, vitest_1.afterEach)(() => {
        vitest_1.vi.unstubAllGlobals();
    });
    (0, vitest_1.it)('appelle fetch avec les bons headers', async () => {
        vitest_1.vi.mocked(fetch).mockResolvedValueOnce({
            ok: true,
            json: async () => MOCK_RESPONSE,
        });
        await (0, brain_1.callBrain)(MOCK_INPUT);
        (0, vitest_1.expect)(fetch).toHaveBeenCalledOnce();
        const [url, opts] = vitest_1.vi.mocked(fetch).mock.calls[0];
        (0, vitest_1.expect)(url).toContain('agent-brain');
        (0, vitest_1.expect)(opts.method).toBe('POST');
        (0, vitest_1.expect)(opts.headers).toMatchObject({
            'Content-Type': 'application/json',
            'Authorization': vitest_1.expect.stringContaining('Bearer'),
        });
    });
    (0, vitest_1.it)('envoie le body JSON correct', async () => {
        vitest_1.vi.mocked(fetch).mockResolvedValueOnce({
            ok: true,
            json: async () => MOCK_RESPONSE,
        });
        await (0, brain_1.callBrain)(MOCK_INPUT);
        const [, opts] = vitest_1.vi.mocked(fetch).mock.calls[0];
        const body = JSON.parse(opts.body);
        (0, vitest_1.expect)(body.agentId).toBe('command');
        (0, vitest_1.expect)(body.content).toBe('quel est le score global ?');
        (0, vitest_1.expect)(body.sourceChannel).toBe('discord_channel');
    });
    (0, vitest_1.it)('retourne la réponse du brain', async () => {
        vitest_1.vi.mocked(fetch).mockResolvedValueOnce({
            ok: true,
            json: async () => MOCK_RESPONSE,
        });
        const result = await (0, brain_1.callBrain)(MOCK_INPUT);
        (0, vitest_1.expect)(result.responseText).toBe('Score global : 7/10');
        (0, vitest_1.expect)(result.conversationId).toBe('conv-123');
    });
    (0, vitest_1.it)('retente une fois sur 5xx', async () => {
        vitest_1.vi.mocked(fetch)
            .mockResolvedValueOnce({ ok: false, status: 503, text: async () => 'Service Unavailable' })
            .mockResolvedValueOnce({ ok: true, json: async () => MOCK_RESPONSE });
        const result = await (0, brain_1.callBrain)(MOCK_INPUT);
        (0, vitest_1.expect)(fetch).toHaveBeenCalledTimes(2);
        (0, vitest_1.expect)(result.responseText).toBe('Score global : 7/10');
    });
    (0, vitest_1.it)('throw si la 2ème tentative échoue aussi', async () => {
        vitest_1.vi.mocked(fetch)
            .mockResolvedValueOnce({ ok: false, status: 500, text: async () => 'error' })
            .mockResolvedValueOnce({ ok: false, status: 500, text: async () => 'error again' });
        await (0, vitest_1.expect)((0, brain_1.callBrain)(MOCK_INPUT)).rejects.toThrow('Brain API error 500');
    });
    (0, vitest_1.it)('throw sur erreur 4xx sans retry', async () => {
        vitest_1.vi.mocked(fetch).mockResolvedValueOnce({
            ok: false,
            status: 401,
            text: async () => 'Unauthorized',
        });
        await (0, vitest_1.expect)((0, brain_1.callBrain)(MOCK_INPUT)).rejects.toThrow('Brain API error 401');
        (0, vitest_1.expect)(fetch).toHaveBeenCalledOnce();
    });
    (0, vitest_1.it)('throw sur timeout (AbortError)', async () => {
        vitest_1.vi.mocked(fetch).mockRejectedValueOnce(Object.assign(new Error('The operation was aborted'), { name: 'AbortError' }));
        await (0, vitest_1.expect)((0, brain_1.callBrain)(MOCK_INPUT)).rejects.toThrow();
    });
});
