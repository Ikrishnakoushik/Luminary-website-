const fs = require('fs');
let code = fs.readFileSync('public/profile.html', 'utf8');

const targetStr = '<h2 class="feed-heading" id="spreads-title">Recent spreads</h2>';

const insertion = `
            <!-- Projects Section -->
            <section id="projects-section" style="display: none; background: var(--surface); padding: 25px; border-radius: 12px; border: 1px solid var(--border); margin-bottom: 25px; margin-top: 20px;">
                <div class="section-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;">
                    <h2 class="section-title" style="font-size: 1.25rem;">Projects</h2>
                    <button class="auth-btn btn-sm" id="add-project-btn" style="display:none; width: auto;" onclick="openModal('projectModal')"><i class="fas fa-plus"></i> Add Project</button>
                </div>
                <div id="projects-grid" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 15px;">
                    <!-- Projects injected here -->
                </div>
            </section>

            <!-- Interests Section -->
            <section id="interests-section" style="display: none; background: var(--surface); padding: 25px; border-radius: 12px; border: 1px solid var(--border); margin-bottom: 25px; margin-top: 20px;">
                <div class="section-header">
                    <h2 class="section-title" style="font-size: 1.25rem;">Interests</h2>
                </div>
                <div id="interests-list" style="display: flex; flex-wrap: wrap; gap: 10px; margin-top: 15px;">
                    <!-- Interests injected here -->
                </div>
            </section>

            <!-- POSTS CONTAINER -->
            <div id="posts-container" style="margin-top: 20px; width: 100%;"></div>
`;

code = code.replace(targetStr, targetStr + '\n' + insertion);

fs.writeFileSync('public/profile.html', code);
console.log('Successfully patched profile.html');
