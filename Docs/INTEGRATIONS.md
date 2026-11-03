# Set up your Notchest workspace

These features are in the development build after 0.6.0. The published 0.6.0
DMG does not contain them yet. English is the default; Arabic is optional.

## First launch and your overview

First launch offers Developer, Focus and Everyday presets. Each selects four
home cards. Settings lets you show, hide and reorder individual cards, reopen
setup, choose log/project folders, and adjust background transparency.
At least one home card remains visible. Existing notes and island dimensions
are preserved. Reduce Transparency and Increase Contrast override the glass
appearance for readability.

## AI usage and limits

Local Codex and Claude Code summaries appear together. Each log directory can
be selected independently. Scans run every five seconds; their results depend
on the provider writing usage records. Enable recurring Codex account limits
to query the signed-in CLI every minute. Local tracking and account access
remain independent. No inference request is made to read limits.

Optional alerts appear inside Notchest at 80% and 95% usage. A threshold is
reported once per observed reset window. Expired snapshots do not generate
alerts. The app does not invent account limits for Claude or other providers.
Tokens from local logs are not a financial bill or subscription balance.

## Agent task states

1. Move the application to its intended permanent location first, normally
   Applications. Hook commands point to its bundled `NotchestCommand` helper.
2. Open Developer > Activity and enable Local API. It listens on loopback
   only, uses a rotating token, and remains off on the next app launch.
3. Choose Codex or Claude Code > Install integration. The app shows the scope
   before changing configuration and saves an owner-readable local backup.
4. Restart the coding tool. Codex requires review and trust of new hooks in
   `/hooks` or Settings > Hooks. Complete that review inside Codex yourself.
   Use a tool version that supports lifecycle hooks; older versions may need
   upgrading. Managed policies can prevent hooks from running.
5. Start a task. Notchest displays Working, Needs attention, Turn completed,
   or Stopped, using the task-state events it receives. Return to the original
   coding tool to review and approve requests.

Codex configuration: `CODEX_HOME/hooks.json`, otherwise `~/.codex/hooks.json`.
Claude configuration: `CLAUDE_CONFIG_DIR/settings.json`, otherwise
`~/.claude/settings.json`. Existing hooks and other settings are preserved.
Remove integration removes only the Notchest hook entries and keeps a backup.
Reinstall the integration after moving/renaming the app bundle.

The helper discards prompts, tool arguments, answers and transcript paths. It
posts only provider, hashed session identity, project basename and event state
on this Mac. It always prints empty JSON and never returns an approval,
rejection or continuation decision. This is an observer, not a remote-control
interface. A hook `Stop` describes a turn-stop event; it does not prove that
all tests passed. Build results come from explicit command exits or GitHub
workflow results. If the app is unavailable the helper exits without blocking
the coding tool.

The API token is stored only while enabled in an owner-readable runtime file
under `~/Library/Application Support/Notchest/Runtime`. It is removed on
normal shutdown/disable and replaced with a new token next time.

References: [Codex hooks](https://learn.chatgpt.com/docs/hooks),
[Claude Code hooks](https://code.claude.com/docs/en/hooks).

## Project builds and tests

Choose a local Git repository, sign in with GitHub CLI (`gh auth login`), and
enable GitHub Actions in Developer > Activity. The app checks up to eight
recent workflow runs every minute, shows four in the card, and opens their
GitHub results on click. State changes produce local activities. The initial
scan does not announce historical completed runs. Local command runs also
report start/exit status without changing the active tab on completion.

This reads workflow status; it does not execute or modify repository code.
See [GitHub CLI run list](https://cli.github.com/manual/gh_run_list).

## Releases and Apple signing

Settings > Updates can check the repository's latest stable release manually,
or every six hours after you opt in. It opens the official release download
page. Installation remains manual.

Developer ID signing, Apple notarization and unattended installation are
**deferred at the project owner's request** until an Apple Developer account
is ready. Development packaging keeps the existing local ad-hoc signature;
no Apple credentials, paid membership, notarization submission or new
security exception is requested by this work.
