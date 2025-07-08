require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const User = require('./models/User');
const connectMongo = require('./services/mongo');
const redisClient = require('./services/redis'); // updated import for ioredis

const client = require('prom-client');
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics();

const app = express();
app.use(cors());
app.use(bodyParser.json());

const startServer = async () => {
  try {
    // Connect to MongoDB
    await connectMongo();
    console.log('✅ Connected to MongoDB');

    // Redis test
    await redisClient.set('greeting', 'Hello from Redis via Sentinel!');
    const greeting = await redisClient.get('greeting');
    console.log('🔁 Redis greeting:', greeting);

    /// Metrics endpoint for Prometheus
    app.get('/metrics', async (req, res) => {
      res.set('Content-Type', client.register.contentType);
      res.end(await client.register.metrics());
    });

    // Create user
    app.post('/api/users', async (req, res) => {
      try {
        const { name, email } = req.body;
        const user = new User({ name, email });
        await user.save();
        res.status(201).json({ message: 'User created', user });
      } catch (err) {
        console.error('❌ Error creating user:', err);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    // Get single user with Redis caching
    app.get('/api/users/:email', async (req, res) => {
      const email = req.params.email;

      try {
        const cachedUser = await redisClient.get(`user:${email}`);
        if (cachedUser) {
          console.log('🧠 Cache hit for', email);
          return res.json(JSON.parse(cachedUser));
        }

        const user = await User.findOne({ email });
        if (!user) return res.status(404).json({ error: 'User not found' });

        await redisClient.set(`user:${email}`, JSON.stringify(user), 'EX', 300);
        console.log('📦 Cached user in Redis:', user.name);
        res.json(user);
      } catch (err) {
        console.error('❌ Error fetching user:', err);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    // Get all users
    app.get('/api/users', async (req, res) => {
      try {
        const users = await User.find();
        res.json(users);
      } catch (err) {
        console.error('❌ Error fetching users:', err);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    // Update user
    app.put('/api/users/:email', async (req, res) => {
      const { email: oldEmail } = req.params;
      const { name, email: newEmail } = req.body;

      try {
        const user = await User.findOne({ email: oldEmail });
        if (!user) return res.status(404).json({ error: 'User not found' });

        user.name = name;
        if (newEmail && newEmail !== oldEmail) {
          user.email = newEmail;
          await redisClient.del(`user:${oldEmail}`);
        }

        await user.save();
        await redisClient.set(`user:${user.email}`, JSON.stringify(user), 'EX', 300);

        res.json({ message: 'User updated', user });
      } catch (err) {
        console.error('❌ Error updating user:', err);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    // Delete user
    app.delete('/api/users/:email', async (req, res) => {
      const email = req.params.email;

      try {
        const deletedUser = await User.findOneAndDelete({ email });
        if (!deletedUser) return res.status(404).json({ error: 'User not found' });

        await redisClient.del(`user:${email}`);
        res.json({ message: 'User deleted', user: deletedUser });
      } catch (err) {
        console.error('❌ Error deleting user:', err);
        res.status(500).json({ error: 'Internal server error' });
      }
    });

    const PORT = process.env.PORT || 3000;
    app.listen(PORT, () => {
      console.log(`🚀 Server running on port ${PORT}`);
    });
  } catch (err) {
    console.error('❌ Failed to start app:', err);
    process.exit(1);
  }
};

startServer();

