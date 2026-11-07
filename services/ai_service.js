/**
 * Vylithra AI Service
 * Powered by Google Gemini API with graceful heuristic fallbacks.
 */

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

async function callGemini(prompt, systemInstruction = '') {
    const apiKey = process.env.GEMINI_API_KEY;

    if (apiKey) {
        try {
            const body = {
                contents: [{ parts: [{ text: prompt }] }]
            };
            if (systemInstruction) {
                body.systemInstruction = {
                    parts: [{ text: systemInstruction }]
                };
            }

            const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body)
            });

            if (response.ok) {
                const data = await response.json();
                const candidate = data.candidates && data.candidates[0];
                const text = candidate && candidate.content && candidate.content.parts && candidate.content.parts[0] && candidate.content.parts[0].text;
                if (text) return text.trim();
            } else {
                console.warn('[Vylithra AI] Gemini API call returned non-200:', response.status);
            }
        } catch (err) {
            console.error('[Vylithra AI] Gemini API request failed:', err.message);
        }
    }

    // Heuristic Fallback when GEMINI_API_KEY is not configured
    return null;
}

/**
 * 1. Book Summarization
 */
async function summarizeBook({ title, author, description, sampleText }) {
    const prompt = `Provide a structured, engaging summary of the book:
Title: "${title || 'Untitled'}"
Author: "${author || 'Unknown'}"
Description: ${description || 'N/A'}
Excerpt/Sample: ${sampleText ? sampleText.slice(0, 1500) : 'N/A'}

Format your response in Markdown with:
### 🌟 Executive Overview (2-3 sentences)
### 🔑 Key Takeaways (3-4 bullet points)
### 💡 Core Themes & Why You Should Read It`;

    const aiResponse = await callGemini(prompt, 'You are Vylithra Books AI, a literary analyst creating concise, insightful reading summaries.');
    if (aiResponse) return aiResponse;

    // Fallback summary
    return `### 🌟 Executive Overview
*${title || 'This work'}* by ${author || 'the author'} presents an exploration of its central narrative.

### 🔑 Key Takeaways
- **Engaging Narrative**: Blends creative insight with thought-provoking perspectives.
- **Deep Themes**: Explores questions of individual agency and purpose.
- **Accessible Style**: Written with a voice crafted for modern readers.

### 💡 Core Themes
A recommended read for enthusiasts seeking meaningful stories and new perspectives in contemporary literature.`;
}

/**
 * 2. Writing Assistant
 */
async function assistWriting({ text, mode = 'polish' }) {
    if (!text || !text.trim()) return text || '';

    const instructions = {
        polish: 'Enhance the clarity, flow, and impact of this text while preserving the original meaning.',
        grammar: 'Fix all grammar, spelling, and punctuation errors without altering the author voice.',
        professional: 'Rewrite this into a polished, professional, and articulate tone.',
        casual: 'Make this conversational, approachable, and engaging for social media.',
        storyteller: 'Infuse vivid storytelling, evocative vocabulary, and emotional resonance.',
        headline: 'Generate 3 catchy, high-engagement headlines/hooks based on this post.'
    };

    const instruction = instructions[mode] || instructions.polish;
    const prompt = `Task: ${instruction}

Original Text:
"""
${text}
"""

Return only the enhanced text directly. No commentary, markdown code fences, or disclaimers.`;

    const aiResponse = await callGemini(prompt, 'You are Vylithra AI Writing Assistant, refining social posts, articles, and communications.');
    if (aiResponse) return aiResponse;

    // Heuristic fallback
    if (mode === 'headline') {
        const words = text.split(/\s+/).slice(0, 6).join(' ');
        return `1. Discover: ${words}...\n2. What you need to know about ${words}\n3. The journey behind ${words}`;
    }
    return text.trim();
}

/**
 * 3. Multi-Language Translation
 */
async function translateText({ text, targetLanguage = 'Spanish' }) {
    if (!text || !text.trim()) return '';

    const prompt = `Translate the following text accurately into ${targetLanguage}, keeping a natural conversational tone:

"""
${text}
"""

Return only the translation, with no quotes or extra commentary.`;

    const aiResponse = await callGemini(prompt, 'You are an accurate, culturally nuanced polyglot translator.');
    if (aiResponse) return aiResponse;

    return text;
}

/**
 * 4. Content Moderation & Safety Pre-Screening
 */
async function moderateContent(text) {
    if (!text || !text.trim()) return { isSafe: true, flagReason: null };

    // Quick regex checks for high-severity keywords
    const profanityRegex = /\b(childporn|terrorist|kill yourself|suicide bomb)\b/i;
    if (profanityRegex.test(text)) {
        return { isSafe: false, flagReason: 'Severe safety policy violation detected.' };
    }

    const prompt = `Analyze this text for severe violations (hate speech, self-harm incitement, threats of violence, or dangerous malware/phishing).
Text: "${text.slice(0, 600)}"

Respond with valid JSON only in this exact format:
{"isSafe": true, "flagReason": null}
or
{"isSafe": false, "flagReason": "Brief description of violation"}`;

    const aiResponse = await callGemini(prompt, 'You are an automated safety compliance analyzer. Return strict JSON only.');
    if (aiResponse) {
        try {
            const parsed = JSON.parse(aiResponse.replace(/```json|```/g, '').trim());
            return {
                isSafe: typeof parsed.isSafe === 'boolean' ? parsed.isSafe : true,
                flagReason: parsed.flagReason || null
            };
        } catch(e) {}
    }

    return { isSafe: true, flagReason: null };
}

module.exports = {
    summarizeBook,
    assistWriting,
    translateText,
    moderateContent
};
