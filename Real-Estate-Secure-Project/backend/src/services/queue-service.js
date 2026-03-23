const { Queue, Worker, QueueEvents } = require('bullmq');

const { config } = require('../config');
const { getRedis } = require('./redis-service');

const queueRegistry = new Map();
const queueEventsRegistry = new Map();

function getQueue(name) {
  if (!config.redisUrl) {
    return null;
  }
  if (!queueRegistry.has(name)) {
    queueRegistry.set(
      name,
      new Queue(name, {
        prefix: config.queuePrefix,
        connection: getRedis(),
        defaultJobOptions: {
          removeOnComplete: 250,
          removeOnFail: 500,
          attempts: 5,
          backoff: {
            type: 'exponential',
            delay: 5000,
          },
        },
      }),
    );
  }
  return queueRegistry.get(name);
}

function getQueueEvents(name) {
  if (!config.redisUrl) {
    return null;
  }
  if (!queueEventsRegistry.has(name)) {
    queueEventsRegistry.set(
      name,
      new QueueEvents(name, {
        prefix: config.queuePrefix,
        connection: getRedis(),
      }),
    );
  }
  return queueEventsRegistry.get(name);
}

async function enqueue(name, jobName, payload, options = {}) {
  const queue = getQueue(name);
  if (!queue) {
    return null;
  }
  return queue.add(jobName, payload, options);
}

function createWorker(name, processor) {
  if (!config.redisUrl) {
    return null;
  }
  return new Worker(name, processor, {
    prefix: config.queuePrefix,
    connection: getRedis(),
    concurrency: 10,
  });
}

module.exports = {
  createWorker,
  enqueue,
  getQueue,
  getQueueEvents,
};
