const fs = require('fs');

const files = ['public/auth.html', 'public/index.html'];

const cssToInject = `
        /* === DYNAMIC TEXT ANIMATION === */
        .hero-title {
            line-height: 1.2;
            margin-bottom: 15px;
            font-size: clamp(2.5rem, 5vw, 4rem);
        }

        .word-slider {
            display: inline-block;
            vertical-align: bottom;
            height: 1.2em;
            overflow: hidden;
            position: relative;
            white-space: nowrap;
        }

        .word-slider-track {
            display: flex;
            flex-direction: column;
            animation: slideWords 9s cubic-bezier(0.16, 1, 0.3, 1) infinite;
        }

        .word-slider .word {
            height: 1.2em;
            display: flex;
            align-items: center;
        }

        @keyframes slideWords {
            0%, 25% { transform: translateY(0); }
            33%, 58% { transform: translateY(-1.2em); }
            66%, 91% { transform: translateY(-2.4em); }
            100% { transform: translateY(-3.6em); } /* Reset cleanly */
        }

        /* Smooth Fade In Elements */
        .fade-up {
            animation: fadeUpAnim 1s cubic-bezier(0.16, 1, 0.3, 1) forwards;
            opacity: 0;
            transform: translateY(20px);
        }
        .delay-1 { animation-delay: 0.2s; }
        .delay-2 { animation-delay: 0.4s; }

        @keyframes fadeUpAnim {
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
`;

files.forEach(file => {
    try {
        let html = fs.readFileSync(file, 'utf8');

        // 1. Inject CSS
        if (!html.includes('/* === DYNAMIC TEXT ANIMATION === */')) {
            const styleClose = html.indexOf('</style>');
            html = html.substring(0, styleClose) + cssToInject + html.substring(styleClose);
        }

        // 2. Replace H1
        const h1Regex = /<h1>The Future of Digital<br>Publishing<\/h1>/;
        const newH1 = `<h1 class="hero-title fade-up">
                The Future of<br>
                <span class="word-slider">
                    <span class="word-slider-track">
                        <span class="word">Digital Publishing.</span>
                        <span class="word" style="background: linear-gradient(135deg, var(--primary), var(--secondary)); -webkit-background-clip: text; -webkit-text-fill-color: transparent;">Visual Storytelling.</span>
                        <span class="word" style="color: #6366f1;">Creative Freedom.</span>
                        <span class="word">Digital Publishing.</span> <!-- Duplicate for seamless loop -->
                    </span>
                </span>
            </h1>`;
        
        if(html.match(h1Regex)) {
            html = html.replace(h1Regex, newH1);
        }

        // 3. Add fade-up classes
        html = html.replace(/<p>Unleash your creativity/, '<p class="fade-up delay-1">Unleash your creativity');
        html = html.replace(/<div class="cta-group">/, '<div class="cta-group fade-up delay-2">');

        fs.writeFileSync(file, html);
        console.log("Updated " + file);
    } catch(e) {
        console.log("Error with " + file, e);
    }
});
