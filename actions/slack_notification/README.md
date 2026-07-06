# Slack notification

Composite action that resolves Slack recipients from GitHub logins and sends a Block Kit
message via `chat.postMessage`. Replaces the hand-rolled `github-script` Slack blocks
duplicated across `tests`, `branch-deploy`, `install-test` and `publish` workflows.

The bot token needs `users:read`, `users.profile:read` and `chat:write`. 
Recipient resolution matches a GitHub username against a Slack custom profile field (default `Xf0A2BPU8U77`).

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `bot-token` | yes | - | Slack bot token (`secrets.SLACK_GHBOT_TOKEN`). |
| `mode` | yes | - | `channel`, `author`, or `contributors`. See below. |
| `blocks` | yes | - | Block Kit array as a JSON string. Supports `{{ROLE}}`, `{{MENTION}}` and `{{KEY}}` placeholders. |
| `values` | no | `{}` | JSON object of `KEY` → raw string, injected JSON-safely as `{{KEY}}`. Build with `toJSON()`. |
| `channel-id` | no | `C067BD0377F` | Target channel for `mode=channel`. |
| `github-field-id` | no | `Xf0A2BPU8U77` | Slack custom profile field holding the GitHub username. |
| `mention-actor` | no | `false` | `mode=channel`: resolve the actor and expose `{{MENTION}}` as a real ping. |
| `actor` | no | `github.actor` | Actor login. |
| `event-name` | no | `github.event_name` | Drives `contributors` branching. |
| `pr-author` | no | `github.event.pull_request.user.login` | PR author login. |
| `requested-reviewers` | no | `toJSON(...requested_reviewers)` | Reviewers JSON (`contributors`). |

### Modes

- **channel** - post once to `channel-id`. With `mention-actor: true`, `{{MENTION}}` becomes the actor's Slack ping (or plain login if unresolved).
- **author** - DM the PR author. Bots / unresolved authors are skipped silently.
- **contributors** - DM PR author + requested reviewers + pusher; on `workflow_dispatch`, DM the actor. Unresolved users are dropped with a warning.

The send step fails only if **every** send fails; partial failures are warnings.

### Placeholders & escaping

`{{ROLE}}` (per recipient) and `{{MENTION}}` (channel mention) are built-in. Any other
`{{KEY}}` comes from `values`. All substitutions are JSON-escaped, so arbitrary text
(PR titles, commit messages) is safe - **pass such values through `values` using `toJSON()`**,
never inline into the `blocks` string.

## Examples

### Channel post on failure 

```yaml
notify-slack:
  name: Notify on failure
  needs: [build]
  if: failure()
  runs-on: ubuntu-latest
  steps:
    - uses: FlowFuse/github-actions-workflows/actions/slack_notification@slack_notification/v1
      with:
        bot-token: ${{ secrets.SLACK_GHBOT_TOKEN }}
        mode: channel
        blocks: |
          [
            { "type": "header", "text": { "type": "plain_text", "text": ":x: ${{ github.workflow }} workflow failed", "emoji": true } },
            { "type": "divider" },
            { "type": "section", "text": { "type": "mrkdwn", "text": "*Workflow run:*\n<${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View>" } }
          ]
```

### Author DM on PR failure, channel ping on push

```yaml
    - uses: FlowFuse/github-actions-workflows/actions/slack_notification@slack_notification/v1
      with:
        bot-token: ${{ secrets.SLACK_GHBOT_TOKEN }}
        mode: ${{ github.event_name == 'pull_request' && 'author' || 'channel' }}
        mention-actor: ${{ github.event_name != 'pull_request' }}
        blocks: |
          [
            { "type": "header", "text": { "type": "plain_text", "text": ":x: Tests failed", "emoji": true } },
            { "type": "section", "fields": [
              { "type": "mrkdwn", "text": "*Author:* {{MENTION}}" },
              { "type": "mrkdwn", "text": "<${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View failed workflow>" }
            ] }
          ]
```

> `{{MENTION}}` renders the actor ping on push (channel mode); on PR (author mode) it is empty —
> DM recipients already know they are the author, so branch the text with expressions if needed.

### Contributors DM with arbitrary PR title

```yaml
    - uses: FlowFuse/github-actions-workflows/actions/slack_notification@slack_notification/v1
      with:
        bot-token: ${{ secrets.SLACK_GHBOT_TOKEN }}
        mode: contributors
        values: |
          { "PR_TITLE": ${{ toJSON(github.event.pull_request.title) }} }
        blocks: |
          [
            { "type": "header", "text": { "type": "plain_text", "text": "Pull Request ${{ github.event.number }} pre-staging deployment", "emoji": true } },
            { "type": "section", "fields": [
              { "type": "mrkdwn", "text": "*Role:*\n{{ROLE}}" },
              { "type": "mrkdwn", "text": "*Pull Request:*\n{{PR_TITLE}}" }
            ] }
          ]
```
