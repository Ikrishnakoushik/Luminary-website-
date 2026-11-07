/**
 * Vylithra AI Service
 * Powered by Google Gemini API with multi-model failover & heuristic fallbacks.
 */

const GEMINI_MODELS = [
    'gemini-flash-lite-latest',
    'gemini-2.5-flash-lite',
    'gemini-flash-latest',
    'gemini-pro-latest',
    'gemini-3-flash-preview'
];

async function callGemini(prompt, systemInstruction = '') {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) return null;

    for (const model of GEMINI_MODELS) {
        try {
            const body = {
                contents: [{ parts: [{ text: prompt }] }]
            };
            if (systemInstruction) {
                body.systemInstruction = {
                    parts: [{ text: systemInstruction }]
                };
            }

            const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
            const response = await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body),
                signal: AbortSignal.timeout(9000)
            });

            if (response.ok) {
                const data = await response.json();
                const candidate = data.candidates && data.candidates[0];
                const text = candidate && candidate.content && candidate.content.parts && candidate.content.parts[0] && candidate.content.parts[0].text;
                if (text) return text.trim();
            }
        } catch (err) {
            // Try next model in candidate list
        }
    }

    // Heuristic Fallback when API returns 503 or is offline
    return null;
}

/**
 * 1. Book Summarization
 */
async function summarizeBook({ title, author, description, sampleText }) {
    const cleanTitle = title || 'Untitled Work';
    const cleanAuthor = author || 'Vylithra Author';
    const prompt = `Provide a structured, engaging summary of the book:
Title: "${cleanTitle}"
Author: "${cleanAuthor}"
Description: ${description || 'N/A'}
Excerpt/Sample: ${sampleText ? sampleText.slice(0, 2500) : 'N/A'}

Format your response in Markdown with:
### 🌟 Executive Overview (2-3 sentences)
### 🔑 Key Takeaways (3-4 bullet points)
### 💡 Core Themes & Why You Should Read It`;

    const aiResponse = await callGemini(prompt, 'You are Vylithra Books AI, a literary analyst creating concise, insightful reading summaries.');
    if (aiResponse) return aiResponse;

    // Intelligent context-aware fallback
    const descSnippet = description && description.length > 20 
        ? description 
        : `An insightful exploration of ideas, narrative craft, and core human experiences.`;

    return `### 🌟 Executive Overview
*${cleanTitle}* by ${cleanAuthor} is an evocative work that delves into ${descSnippet.slice(0, 180)}...

### 🔑 Key Takeaways
- **Compelling Narrative**: Explores foundational questions of discovery, ambition, and identity.
- **Distinctive Perspective**: Offers thought-provoking commentary and vivid literary craftsmanship.
- **Actionable Insights**: Connects conceptual depth with relatable human experiences.

### 💡 Core Themes & Why You Should Read It
**Core Themes:** Discovery, human agency, reflection, and creative expression.

**Why You Should Read It:**
*${cleanTitle}* provides an enriching reading experience for both casual explorers and dedicated enthusiasts seeking meaningful literature in modern publishing.`;
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
