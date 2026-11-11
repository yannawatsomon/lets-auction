# CI package mirror failures

Last verified: 2026-11-11

PR #102's GitHub-hosted test runner could reach GitHub/Microsoft but repeatedly failed
to resolve Ubuntu archive hosts while installing libvips. No tests had run at that point.
Rerunning once did not fix it; switching Azure HTTP to Ubuntu archive HTTPS also failed
with `Temporary failure resolving 'archive.ubuntu.com'`.

The test workflow now uses the Ubuntu mirror at `https://mirrors.edge.kernel.org/ubuntu/`
through the runner's `/etc/apt/apt-mirrors.txt`. APT repository signatures and required
packages/checks remain unchanged. Download retries/timeouts are bounded so infrastructure
failures surface instead of waiting many minutes per mirror. Re-evaluate this workaround
when runner DNS recovers; do not bypass test checks or disable APT signature verification.
