async function getLatestValidVersion(owner, repo, github, context) {
  try {
    console.log(`Fetching latest ${owner}/${repo}...`);
    try {
      const rel = await github.rest.repos.getLatestRelease({ owner, repo });
      const tag = rel.data.tag_name;
      if (isValidVersionTag(tag)) {
        console.log(`getLatestRelease hit: ${tag}`);
        return tag;
      }
      console.log(`Release tag ${tag} invalid format, fallback to listTags`);
    } catch (e) {
      console.log(`getLatestRelease failed, fallback: ${e.message}`);
    }
    const res = await github.rest.repos.listTags({ owner, repo, per_page: 100 });
    if (!res.data || !res.data.length) { console.log('No tags'); return ''; }
    const valid = res.data.map(t => t.name).filter(isValidVersionTag);
    if (!valid.length) { console.log('No valid tags'); return ''; }
    const sorted = valid.sort((a, b) => compareVersions(b, a));
    console.log(`Top valid: ${sorted.slice(0,5).join(', ')}`);
    return sorted[0];
  } catch (e) { console.error(`getLatestValidVersion error: ${e}`); return ''; }
}
function isValidVersionTag(tag) { return /^v\d+(\.\d+)+$/.test(tag); }
function compareVersions(a, b) {
  const A = a.substring(1).split('.').map(Number);
  const B = b.substring(1).split('.').map(Number);
  const len = Math.max(A.length, B.length);
  for (let i = 0; i < len; i++) {
    const x = A[i] || 0, y = B[i] || 0;
    if (x !== y) return x - y;
  }
  return 0;
}
module.exports = { getLatestValidVersion, isValidVersionTag, compareVersions };
