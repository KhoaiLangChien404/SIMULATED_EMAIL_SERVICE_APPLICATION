const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Route for POST /api/register
app.post('/api/register', (req, res) => {
  const { phone, password, name, twoFactorEnabled } = req.body;
  if (!phone || !password || !name) {
    return res.status(400).json({ message: 'Missing required fields' });
  }
  db.get('SELECT phone FROM users WHERE phone = ?', [phone], (err, row) => {
    if (err) return res.status(500).json({ message: 'Server error' });
    if (row) return res.status(400).json({ message: 'Phone already registered' });
    bcrypt.hash(password, 10, (err, hash) => {
      if (err) return res.status(500).json({ message: 'Server error' });
      db.run(
        'INSERT INTO users (phone, password, name, twoFactorEnabled) VALUES (?, ?, ?, ?)',
        [phone, hash, name, twoFactorEnabled],
        (err) => {
          if (err) return res.status(500).json({ message: 'Server error' });
          res.status(201).json({ message: 'User registered' });
        }
      );
    });
  });
});

// Route for POST /api/login (for completeness)
app.post('/api/login', (req, res) => {
  const { phone, password } = req.body;
  if (!phone || !password) {
    return res.status(400).json({ message: 'Missing required fields' });
  }
  db.get('SELECT * FROM users WHERE phone = ?', [phone], (err, user) => {
    if (err) return res.status(500).json({ message: 'Server error' });
    if (!user) return res.status(400).json({ message: 'User not found' });
    bcrypt.compare(password, user.password, (err, result) => {
      if (err) return res.status(500).json({ message: 'Server error' });
      if (!result) return res.status(400).json({ message: 'Invalid password' });
      const token = jwt.sign({ phone: user.phone }, JWT_SECRET, { expiresIn: '1h' });
      res.status(200).json({ token });
    });
  });
});

// Route for GET /api/user (for completeness)
app.get('/api/user', (req, res) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ message: 'No token provided' });
  jwt.verify(token, JWT_SECRET, (err, decoded) => {
    if (err) return res.status(401).json({ message: 'Invalid token' });
    db.get('SELECT phone, name, twoFactorEnabled FROM users WHERE phone = ?', [decoded.phone], (err, user) => {
      if (err) return res.status(500).json({ message: 'Server error' });
      if (!user) return res.status(404).json({ message: 'User not found' });
      res.status(200).json(user);
    });
  });
});

const db = new sqlite3.Database('email_simulator.db');
const JWT_SECRET = 'your_jwt_secret';

db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS users (
    phone TEXT PRIMARY KEY,
    password TEXT,
    name TEXT,
    profilePicture TEXT,
    twoFactorEnabled BOOLEAN
  )`);
  db.run(`CREATE TABLE IF NOT EXISTS emails (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sender TEXT,
    recipient TEXT,
    subject TEXT,
    body TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    isRead BOOLEAN DEFAULT 0,
    isStarred BOOLEAN DEFAULT 0,
    hasAttachment BOOLEAN DEFAULT 0
  )`);
});

app.listen(3000, () => console.log('Server running on port 3000'));