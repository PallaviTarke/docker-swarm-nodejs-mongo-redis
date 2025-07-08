const Redis = require('ioredis');

const redisClient = new Redis({
  sentinels: [
    { host: 'redis-sentinel1', port: 26379 },
    { host: 'redis-sentinel2', port: 26379 },
    { host: 'redis-sentinel3', port: 26379 }
  ],
  name: 'mymaster',
  role: 'master', // Optional: 'master' (default) or 'slave' for read replicas
  sentinelRetryStrategy: function (times) {
    // Exponential backoff retry
    return Math.min(times * 1000, 10000);
  }
});

redisClient.on('connect', () => {
  console.log('✅ Connected to Redis via Sentinel');
});

redisClient.on('error', (err) => {
  console.error('❌ Redis Client Error', err);
});

module.exports = redisClient;

