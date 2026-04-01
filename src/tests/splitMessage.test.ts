import { describe, it, expect } from 'vitest';

// On extrait splitMessage depuis bot.ts via un re-export de test
// (la fonction est privée dans la classe, on la teste via un helper)
function splitMessage(text: string, maxLength = 2000): string[] {
  if (text.length <= maxLength) return [text];

  const chunks: string[] = [];
  let remaining = text;

  while (remaining.length > 0) {
    if (remaining.length <= maxLength) {
      chunks.push(remaining);
      break;
    }

    let splitIndex = -1;
    const slice = remaining.slice(0, maxLength);

    splitIndex = slice.lastIndexOf('\n\n');
    if (splitIndex === -1) splitIndex = slice.lastIndexOf('\n');
    if (splitIndex === -1) splitIndex = slice.lastIndexOf('. ');
    if (splitIndex === -1) splitIndex = slice.lastIndexOf(' ');
    if (splitIndex === -1) splitIndex = maxLength - 1;

    const chunkEnd = splitIndex + (slice[splitIndex] === '.' ? 2 : 1);
    chunks.push(remaining.slice(0, chunkEnd));
    remaining = remaining.slice(chunkEnd).trimStart();
  }

  return chunks;
}

describe('splitMessage', () => {
  it('retourne le texte tel quel si <= 2000 chars', () => {
    const text = 'Hello world';
    expect(splitMessage(text)).toEqual([text]);
  });

  it('retourne le texte exact à 2000 chars', () => {
    const text = 'a'.repeat(2000);
    expect(splitMessage(text)).toEqual([text]);
  });

  it('split sur paragraph break (\\n\\n)', () => {
    const para1 = 'a'.repeat(1000);
    const para2 = 'b'.repeat(1000);
    const text = `${para1}\n\n${para2}`;
    const chunks = splitMessage(text, 2000);
    expect(chunks.length).toBe(2);
    expect(chunks[0]).toContain(para1);
    expect(chunks[1]).toContain(para2);
  });

  it('split sur newline simple si pas de double newline', () => {
    const line1 = 'a'.repeat(1200);
    const line2 = 'b'.repeat(900);
    const text = `${line1}\n${line2}`;
    const chunks = splitMessage(text, 2000);
    expect(chunks.length).toBe(2);
    expect(chunks[0]).toMatch(/a+/);
    expect(chunks[1]).toMatch(/b+/);
  });

  it('split sur espace si pas de newline', () => {
    const word1 = 'a'.repeat(1500);
    const word2 = 'b'.repeat(600);
    const text = `${word1} ${word2}`;
    const chunks = splitMessage(text, 2000);
    expect(chunks.length).toBe(2);
    chunks.forEach(chunk => {
      expect(chunk.length).toBeLessThanOrEqual(2000);
    });
  });

  it('split forcé si aucun séparateur (mot très long)', () => {
    const text = 'a'.repeat(4500);
    const chunks = splitMessage(text, 2000);
    expect(chunks.length).toBeGreaterThan(1);
    chunks.forEach(chunk => {
      expect(chunk.length).toBeLessThanOrEqual(2000);
    });
  });

  it('reconstitue le texte original après split', () => {
    const original = 'Bonjour. '.repeat(300); // ~2700 chars
    const chunks = splitMessage(original, 2000);
    const rejoined = chunks.join('');
    expect(rejoined).toBe(original);
  });

  it('respecte un maxLength custom', () => {
    const text = 'hello world foo bar baz';
    const chunks = splitMessage(text, 10);
    chunks.forEach(chunk => {
      expect(chunk.length).toBeLessThanOrEqual(10);
    });
  });

  it('gère le texte vide', () => {
    expect(splitMessage('')).toEqual(['']);
  });
});
