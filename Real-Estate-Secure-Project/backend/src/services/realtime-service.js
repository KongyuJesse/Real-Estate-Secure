const EventEmitter = require('events');

const { getRedis } = require('./redis-service');

const emitter = new EventEmitter();
let subscribed = false;

function channelName(topic) {
  return `realtime:${topic}`;
}

async function ensureRedisSubscription() {
  const redis = getRedis();
  if (!redis || subscribed) {
    return;
  }
  subscribed = true;
  const subscriber = redis.duplicate();
  await subscriber.connect().catch(() => null);
  await subscriber.psubscribe('realtime:*').catch(() => null);
  subscriber.on('pmessage', (pattern, channel, message) => { // eslint-disable-line no-unused-vars
    try {
      emitter.emit(channel, JSON.parse(message));
    } catch (error) {
      emitter.emit(channel, message);
    }
  });
}

async function publish(topic, payload) {
  const channel = channelName(topic);
  emitter.emit(channel, payload);
  const redis = getRedis();
  if (redis) {
    await ensureRedisSubscription();
    await redis.publish(channel, JSON.stringify(payload)).catch(() => {});
  }
}

function subscribe(topic, listener) {
  const channel = channelName(topic);
  emitter.on(channel, listener);
  void ensureRedisSubscription();
  return () => {
    emitter.off(channel, listener);
  };
}

module.exports = {
  publish,
  subscribe,
};
