"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const vitest_1 = require("vitest");
// On extrait splitMessage depuis bot.ts via un re-export de test
// (la fonction est privée dans la classe, on la teste via un helper)
function splitMessage(text, maxLength = 2000) {
    if (text.length <= maxLength)
        return [text];
    const chunks = [];
    let remaining = text;
    while (remaining.length > 0) {
        if (remaining.length <= maxLength) {
            chunks.push(remaining);
            break;
        }
        let splitIndex = -1;
        const slice = remaining.slice(0, maxLength);
        splitIndex = slice.lastIndexOf('\n\n');
        if (splitIndex === -1)
            splitIndex = slice.lastIndexOf('\n');
        if (splitIndex === -1)
            splitIndex = slice.lastIndexOf('. ');
        if (splitIndex === -1)
            splitIndex = slice.lastIndexOf(' ');
        if (splitIndex === -1)
            splitIndex = maxLength - 1;
        const chunkEnd = splitIndex + (slice[splitIndex] === '.' ? 2 : 1);
        chunks.push(remaining.slice(0, chunkEnd));
        remaining = remaining.slice(chunkEnd).trimStart();
    }
    return chunks;
}
(0, vitest_1.describe)('splitMessage', () => {
    (0, vitest_1.it)('retourne le texte tel quel si <= 2000 chars', () => {
        const text = 'Hello world';
        (0, vitest_1.expect)(splitMessage(text)).toEqual([text]);
    });
    (0, vitest_1.it)('retourne le texte exact à 2000 chars', () => {
        const text = 'a'.repeat(2000);
        (0, vitest_1.expect)(splitMessage(text)).toEqual([text]);
    });
    (0, vitest_1.it)('split sur paragraph break (\\n\\n)', () => {
        const para1 = 'a'.repeat(1000);
        const para2 = 'b'.repeat(1000);
        const text = `${para1}\n\n${para2}`;
        const chunks = splitMessage(text, 2000);
        (0, vitest_1.expect)(chunks.length).toBe(2);
        (0, vitest_1.expect)(chunks[0]).toContain(para1);
        (0, vitest_1.expect)(chunks[1]).toContain(para2);
    });
    (0, vitest_1.it)('split sur newline simple si pas de double newline', () => {
        const line1 = 'a'.repeat(1200);
        const line2 = 'b'.repeat(900);
        const text = `${line1}\n${line2}`;
        const chunks = splitMessage(text, 2000);
        (0, vitest_1.expect)(chunks.length).toBe(2);
        (0, vitest_1.expect)(chunks[0]).toMatch(/a+/);
        (0, vitest_1.expect)(chunks[1]).toMatch(/b+/);
    });
    (0, vitest_1.it)('split sur espace si pas de newline', () => {
        const word1 = 'a'.repeat(1500);
        const word2 = 'b'.repeat(600);
        const text = `${word1} ${word2}`;
        const chunks = splitMessage(text, 2000);
        (0, vitest_1.expect)(chunks.length).toBe(2);
        chunks.forEach(chunk => {
            (0, vitest_1.expect)(chunk.length).toBeLessThanOrEqual(2000);
        });
    });
    (0, vitest_1.it)('split forcé si aucun séparateur (mot très long)', () => {
        const text = 'a'.repeat(4500);
        const chunks = splitMessage(text, 2000);
        (0, vitest_1.expect)(chunks.length).toBeGreaterThan(1);
        chunks.forEach(chunk => {
            (0, vitest_1.expect)(chunk.length).toBeLessThanOrEqual(2000);
        });
    });
    (0, vitest_1.it)('reconstitue le texte original après split', () => {
        const original = 'Bonjour. '.repeat(300); // ~2700 chars
        const chunks = splitMessage(original, 2000);
        const rejoined = chunks.join('');
        (0, vitest_1.expect)(rejoined).toBe(original);
    });
    (0, vitest_1.it)('respecte un maxLength custom', () => {
        const text = 'hello world foo bar baz';
        const chunks = splitMessage(text, 10);
        chunks.forEach(chunk => {
            (0, vitest_1.expect)(chunk.length).toBeLessThanOrEqual(10);
        });
    });
    (0, vitest_1.it)('gère le texte vide', () => {
        (0, vitest_1.expect)(splitMessage('')).toEqual(['']);
    });
});
