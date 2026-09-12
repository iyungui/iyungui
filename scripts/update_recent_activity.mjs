import { readFile, writeFile } from 'node:fs/promises';

const username = 'iyungui';
const profileRepository = `${username}/${username}`;
const readmePath = new URL('../README.md', import.meta.url);
const startMarker = '<!-- ACTIVITY:START -->';
const endMarker = '<!-- ACTIVITY:END -->';

const response = await fetch(`https://api.github.com/users/${username}/events/public?per_page=100`, {
  headers: {
    Accept: 'application/vnd.github+json',
    ...(process.env.GITHUB_TOKEN ? { Authorization: `Bearer ${process.env.GITHUB_TOKEN}` } : {}),
    'User-Agent': `${profileRepository}-recent-activity`
  }
});

if (!response.ok) {
  throw new Error(`GitHub public-events request failed: ${response.status} ${response.statusText}`);
}

const eventLine = (event) => {
  const repository = event.repo?.name;
  if (!repository) return null;
  const link = `[${repository}](https://github.com/${repository})`;

  switch (event.type) {
    case 'PushEvent':
      return `- Pushed to ${link}.`;
    case 'CreateEvent':
      return event.payload?.ref_type === 'repository' ? `- Created ${link}.` : null;
    case 'PullRequestEvent':
      return `- ${event.payload?.action ?? 'Updated'} a pull request in ${link}.`;
    case 'IssuesEvent':
      return `- ${event.payload?.action ?? 'Updated'} an issue in ${link}.`;
    case 'ReleaseEvent':
      return `- Published a release in ${link}.`;
    default:
      return null;
  }
};

const lines = [];
const seen = new Set();
for (const event of await response.json()) {
  if (event.actor?.login !== username || event.repo?.name === profileRepository) continue;
  const line = eventLine(event);
  if (line && !seen.has(line)) {
    lines.push(line);
    seen.add(line);
  }
  if (lines.length === 3) break;
}

if (lines.length === 0) lines.push('- Building quietly.');

const readme = await readFile(readmePath, 'utf8');
const start = readme.indexOf(startMarker);
const end = readme.indexOf(endMarker);
if (start === -1 || end === -1 || start >= end) {
  throw new Error('Recent activity markers are missing or out of order.');
}

const updated = `${readme.slice(0, start + startMarker.length)}\n${lines.join('\n')}\n${readme.slice(end)}`;
await writeFile(readmePath, updated);
console.log(`Updated recent activity with ${lines.length} public event${lines.length === 1 ? '' : 's'}.`);
