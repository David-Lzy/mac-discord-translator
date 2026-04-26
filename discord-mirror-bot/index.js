import { Client, GatewayIntentBits, Partials, WebhookClient } from 'discord.js';

const required = [
  'DISCORD_BOT_TOKEN',
  'DISCORD_GUILD_ID',
  'VLLM_BASE_URL',
  'VLLM_MODEL'
];

const LANGUAGE_NAMES = {
  en: 'English',
  zh: 'Simplified Chinese',
  ja: 'Japanese',
  fr: 'French',
  de: 'German',
  es: 'Spanish',
  ru: 'Russian',
};

for (const key of required) {
  if (!process.env[key]) {
    console.error(`Missing required env: ${key}`);
    process.exit(1);
  }
}

function parseChannelGroups() {
  const rawGroups = process.env.MIRROR_CHANNEL_GROUPS?.trim();
  if (rawGroups) {
    return rawGroups
      .split(/\r?\n|;/)
      .map((entry) => entry.trim())
      .filter(Boolean)
      .map((entry, index) => {
        const [groupNameRaw, membersRaw] = entry.includes('>')
          ? entry.split('>')
          : [`group${index + 1}`, entry];
        const members = membersRaw
          .split(',')
          .map((member) => member.trim())
          .filter(Boolean)
          .map((member) => {
            const [channelId, languageCode] = member.split('|').map((part) => part.trim());
            if (!channelId || !languageCode || !LANGUAGE_NAMES[languageCode]) {
              throw new Error(`Invalid MIRROR_CHANNEL_GROUPS member: ${member}`);
            }
            return {
              channelId,
              languageCode,
              languageName: LANGUAGE_NAMES[languageCode],
            };
          });

        if (members.length < 2) {
          throw new Error(`Group must contain at least 2 channels: ${entry}`);
        }

        return {
          groupName: groupNameRaw.trim() || `group${index + 1}`,
          members,
        };
      });
  }

  return null;
}

function parseChannelPairs() {
  const rawPairs = process.env.MIRROR_CHANNEL_PAIRS?.trim();
  if (rawPairs) {
    return rawPairs
      .split(/\r?\n|;/)
      .map((entry) => entry.trim())
      .filter(Boolean)
      .map((entry) => {
        const [enChannelId, zhChannelId] = entry.split(':').map((part) => part.trim());
        if (!enChannelId || !zhChannelId) {
          throw new Error(`Invalid MIRROR_CHANNEL_PAIRS entry: ${entry}`);
        }
        return { enChannelId, zhChannelId };
      });
  }

  if (process.env.MIRROR_EN_CHANNEL_ID && process.env.MIRROR_ZH_CHANNEL_ID) {
    return [{
      enChannelId: process.env.MIRROR_EN_CHANNEL_ID,
      zhChannelId: process.env.MIRROR_ZH_CHANNEL_ID
    }];
  }

  if (process.env.MIRROR_CHANNEL_GROUPS?.trim()) {
    return [];
  }

  throw new Error('Missing mirror pair config: set MIRROR_CHANNEL_PAIRS or MIRROR_EN_CHANNEL_ID + MIRROR_ZH_CHANNEL_ID');
}

function pairsToGroups(pairs) {
  return pairs.map((pair, index) => ({
    groupName: `pair${index + 1}`,
    members: [
      {
        channelId: pair.enChannelId,
        languageCode: 'en',
        languageName: LANGUAGE_NAMES.en,
      },
      {
        channelId: pair.zhChannelId,
        languageCode: 'zh',
        languageName: LANGUAGE_NAMES.zh,
      },
    ],
  }));
}

const parsedGroups = parseChannelGroups() || [];
const parsedPairs = pairsToGroups(parseChannelPairs());
const channelGroups = [...parsedGroups, ...parsedPairs];
const channelRoutes = new Map();
for (const group of channelGroups) {
  for (const member of group.members) {
    const targets = group.members
      .filter((target) => target.channelId !== member.channelId)
      .map((target) => ({
        targetChannelId: target.channelId,
        targetLanguageCode: target.languageCode,
        targetLanguageName: target.languageName,
      }));

    channelRoutes.set(member.channelId, {
      groupName: group.groupName,
      sourceLanguageCode: member.languageCode,
      sourceLanguageName: member.languageName,
      targets,
    });
  }
}

const config = {
  token: process.env.DISCORD_BOT_TOKEN,
  guildId: process.env.DISCORD_GUILD_ID,
  channelGroups,
  vllmBaseUrl: process.env.VLLM_BASE_URL.replace(/\/$/, ''),
  vllmModel: process.env.VLLM_MODEL,
  webhookMode: process.env.WEBHOOK_MODE !== 'off',
  mentionOriginalAuthor: process.env.MENTION_ORIGINAL_AUTHOR === 'true'
};

const relayMarker = '[mirror-relay]';
const inFlight = new Set();

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent
  ],
  partials: [Partials.Channel]
});

function directionFor(channelId) {
  return channelRoutes.get(channelId) || null;
}

function sanitizeContent(text) {
  return (text || '').trim();
}

function buildTranslationPrompt({ sourceLang, targetLang, content }) {
  return [
    `Translate the user message from ${sourceLang} to ${targetLang}.`,
    'Return only the translated message.',
    'Preserve links, mentions, emojis, formatting, and line breaks where possible.',
    'Do not add commentary, headers, labels, quotation marks, or explanations.',
    '',
    content
  ].join('\n');
}

async function translate({ sourceLang, targetLang, content }) {
  const response = await fetch(`${config.vllmBaseUrl}/chat/completions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: config.vllmModel,
      temperature: 0,
      max_tokens: 1200,
      messages: [
        {
          role: 'system',
          content: 'You are a precise translation engine.'
        },
        {
          role: 'user',
          content: buildTranslationPrompt({ sourceLang, targetLang, content })
        }
      ]
    })
  });

  if (!response.ok) {
    throw new Error(`vLLM translate failed: HTTP ${response.status}`);
  }

  const data = await response.json();
  const translated = data?.choices?.[0]?.message?.content?.trim();
  if (!translated) {
    throw new Error('vLLM translate failed: empty response');
  }
  return translated;
}

async function getOrCreateWebhook(channel) {
  const hooks = await channel.fetchWebhooks();
  const existing = hooks.find((hook) => hook.owner?.id === client.user.id && hook.name === 'Mirror Relay');
  if (existing) return new WebhookClient({ url: existing.url });

  const created = await channel.createWebhook({
    name: 'Mirror Relay',
    reason: 'Mirror translation relay bot setup'
  });

  return new WebhookClient({ url: created.url });
}

function collectAttachmentFiles(message) {
  return Array.from(message.attachments.values())
    .filter((attachment) => Boolean(attachment.url))
    .map((attachment) => ({
      attachment: attachment.url,
      name: attachment.name || undefined,
      description: attachment.description || undefined,
    }));
}

async function relayMessage({ targetChannel, author, translated, originalMessageUrl, files }) {
  const mention = config.mentionOriginalAuthor ? ` <@${author.id}>` : '';
  const content = `${translated}\n\n${relayMarker} Source: ${originalMessageUrl}${mention}`;

  if (config.webhookMode) {
    const webhook = await getOrCreateWebhook(targetChannel);
    await webhook.send({
      content,
      files,
      username: author.globalName || author.displayName || author.username,
      avatarURL: author.displayAvatarURL({ extension: 'png', size: 128 })
    });
    return;
  }

  await targetChannel.send({
    content: `**${author.globalName || author.displayName || author.username}**\n${content}`,
    files,
  });
}

client.on('ready', () => {
  console.log(`Mirror bot logged in as ${client.user.tag}`);
  console.log(`Guild: ${config.guildId}`);
  for (const group of config.channelGroups) {
    const summary = group.members
      .map((member) => `${member.languageCode.toUpperCase()} ${member.channelId}`)
      .join(' | ');
    console.log(`Group ${group.groupName}: ${summary}`);
  }
});

client.on('messageCreate', async (message) => {
  try {
    if (!message.guild || message.guild.id !== config.guildId) return;
    if (message.author.bot) return;
    if (message.webhookId) return;
    if (message.content?.includes(relayMarker)) return;
    if (inFlight.has(message.id)) return;

    const direction = directionFor(message.channelId);
    if (!direction) return;

    const content = sanitizeContent(message.content);
    const files = collectAttachmentFiles(message);
    if (!content && files.length === 0) return;

    inFlight.add(message.id);
    for (const target of direction.targets) {
      const targetChannel = await client.channels.fetch(target.targetChannelId);
      if (!targetChannel?.isTextBased()) {
        throw new Error(`Target channel not text-based: ${target.targetChannelId}`);
      }

      const translated = content
        ? await translate({
            sourceLang: direction.sourceLanguageName,
            targetLang: target.targetLanguageName,
            content
          })
        : '[attachment only]';

      await relayMessage({
        targetChannel,
        author: message.author,
        translated,
        originalMessageUrl: message.url,
        files,
      });

      console.log(`Relayed ${message.id}: ${message.channelId} -> ${target.targetChannelId} (${direction.sourceLanguageCode} -> ${target.targetLanguageCode})`);
    }
  } catch (error) {
    console.error(`Relay failed for message ${message.id}:`, error);
  } finally {
    inFlight.delete(message.id);
  }
});

client.login(config.token);
