const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const multer = require('multer');
const path = require('path');
const cors = require('cors');
const fs = require('fs');

const app = express();
const corsOptions = {
  origin: 'https://simulated-email-client123.web.app',
  optionsSuccessStatus: 200
};
app.use(cors(corsOptions));
app.use(express.json());

// Ensure uploads directory exists
const uploadDir = 'uploads';
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const originalName = file.originalname || 'uploaded_file';
    const ext = path.extname(originalName) || '.bin';
    cb(null, uniqueSuffix + ext);
  },
});

const upload = multer({ storage: storage });

const db = new sqlite3.Database('email.db', sqlite3.OPEN_READWRITE | sqlite3.OPEN_CREATE, (err) => {
  if (err) console.error('Database connection error:', err);
  console.log('Connected to SQLite database');
  db.run('PRAGMA encoding = "UTF-8"');

  db.run('ALTER TABLE users ADD COLUMN notificationsEnabled BOOLEAN DEFAULT 1', (err) => {
    if (err && !err.message.includes('duplicate column name')) {
      console.error('Error adding notificationsEnabled column:', err);
    }
  });

  db.run('ALTER TABLE emails ADD COLUMN isAutoReply BOOLEAN DEFAULT 0', (err) => {
    if (err && !err.message.includes('duplicate column name')) {
      console.error('Error adding isAutoReply column:', err);
    }
  });

  db.run('ALTER TABLE emails ADD COLUMN isCc BOOLEAN DEFAULT 0', (err) => {
    if (err && !err.message.includes('duplicate column name')) {
      console.error('Error adding isCc column:', err);
    }
  });

  db.run('ALTER TABLE emails ADD COLUMN isBcc BOOLEAN DEFAULT 0', (err) => {
    if (err && !err.message.includes('duplicate column name')) {
      console.error('Error adding isBcc column:', err);
    }
  });

  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      phone TEXT UNIQUE,
      password TEXT,
      name TEXT,
      profilePic TEXT,
      twoFaEnabled BOOLEAN DEFAULT 0,
      autoAnswerEnabled BOOLEAN DEFAULT 0,
      autoAnswerMessage TEXT DEFAULT '',
      defaultFontSize INTEGER DEFAULT 12,
      defaultFontFamily TEXT DEFAULT 'Arial',
      isDarkMode BOOLEAN DEFAULT 0,
      notificationsEnabled BOOLEAN DEFAULT 1
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS emails (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      senderPhone TEXT,
      recipientPhone TEXT,
      cc TEXT DEFAULT '',
      bcc TEXT DEFAULT '',
      subject TEXT,
      body TEXT,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
      isRead BOOLEAN DEFAULT 0,
      isStarred BOOLEAN DEFAULT 0,
      isTrashed BOOLEAN DEFAULT 0,
      isAutoReply BOOLEAN DEFAULT 0,
      isCc BOOLEAN DEFAULT 0,
      isBcc BOOLEAN DEFAULT 0
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS drafts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      senderPhone TEXT,
      recipientPhone TEXT,
      cc TEXT DEFAULT '',
      bcc TEXT DEFAULT '',
      subject TEXT,
      body TEXT,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
      attachment TEXT
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS attachments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      emailId INTEGER,
      filePath TEXT,
      fileType TEXT,
      originalFileName TEXT,
      FOREIGN KEY (emailId) REFERENCES emails(id)
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS labels (
      labelId INTEGER PRIMARY KEY AUTOINCREMENT,
      userId INTEGER,
      label TEXT UNIQUE,
      FOREIGN KEY (userId) REFERENCES users(id)
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS email_labels (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      emailId INTEGER,
      labelId INTEGER,
      FOREIGN KEY (emailId) REFERENCES emails(id),
      FOREIGN KEY (labelId) REFERENCES labels(id),
      UNIQUE(emailId, labelId)
    )
  `);
});

const SECRET_KEY = '8d82733305f00766889c5182cce274f06190bfbafc267659c65d7bce60034bdc3dc9cb497d3d2f0e3f0e5249f42a089dc93704ec50aa184df10863d2f2ce9156';

const authenticate = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token provided' });
  try {
    const decoded = jwt.verify(token, SECRET_KEY);
    req.user = decoded;
    next();
  } catch (err) {
    console.error('Token verification error:', err);
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Registration
app.post('/api/register', upload.single('profilePic'), async (req, res) => {
  const { phone, password, name } = req.body;
  const profilePic = req.file ? `/uploads/${req.file.filename}` : null;
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    db.run(
      'INSERT INTO users (phone, password, name, profilePic, twoFaEnabled, autoAnswerEnabled, isDarkMode, notificationsEnabled) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [phone, hashedPassword, name, profilePic, false, false, false, true],
      (err) => {
        if (err) {
          console.error('Registration error:', err);
          return res.status(400).json({ error: 'Phone number already exists' });
        }
        res.status(201).json({ message: 'User registered' });
      }
    );
  } catch (e) {
    console.error('Registration exception:', e);
    res.status(500).json({ error: 'Server error during registration' });
  }
});

// Login
app.post('/api/login', async (req, res) => {
  const { phone, password } = req.body;
  db.get('SELECT * FROM users WHERE phone = ?', [phone], async (err, user) => {
    if (err) {
      console.error('Login database error:', err);
      return res.status(500).json({ error: 'Server error' });
    }
    if (!user) return res.status(400).json({ error: 'User not found' });
    try {
      const valid = await bcrypt.compare(password, user.password);
      if (!valid) return res.status(400).json({ error: 'Invalid password' });
      const token = jwt.sign({ phone: user.phone, id: user.id }, SECRET_KEY, { expiresIn: '1h' });
      res.json({ token, twoFaEnabled: user.twoFaEnabled });
    } catch (e) {
      console.error('Login exception:', e);
      res.status(500).json({ error: 'Server error' });
    }
  });
});

// Password Recovery
app.post('/api/recover-password', async (req, res) => {
  const { phone, newPassword } = req.body;
  if (!phone || !newPassword) {
    return res.status(400).json({ error: 'Phone number and new password are required' });
  }
  try {
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    db.run(
      'UPDATE users SET password = ? WHERE phone = ?',
      [hashedPassword, phone],
      function (err) {
        if (err) {
          console.error('Password update error:', err);
          return res.status(500).json({ error: 'Server error during password update' });
        }
        if (this.changes === 0) {
          return res.status(404).json({ error: 'User not found' });
        }
        res.status(200).json({ message: 'Password reset successfully' });
      }
    );
  } catch (e) {
    console.error('Password recovery exception:', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// Simulate 2FA verification
app.post('/api/verify-2fa', authenticate, (req, res) => {
  const { code } = req.body;
  if (code === '123456') {
    res.json({ message: '2FA verified' });
  } else {
    res.status(400).json({ error: 'Invalid 2FA code' });
  }
});

// Profile
app.get('/api/profile', authenticate, (req, res) => {
  db.get(
    'SELECT phone, name, profilePic, twoFaEnabled, autoAnswerEnabled, autoAnswerMessage, defaultFontSize, defaultFontFamily, isDarkMode, notificationsEnabled FROM users WHERE phone = ?',
    [req.user.phone],
    (err, user) => {
      if (err) {
        console.error('Profile fetch error:', err);
        return res.status(500).json({ error: 'Server error', details: err.message });
      }
      if (!user) return res.status(400).json({ error: 'User not found' });
      res.json({
        phone: user.phone,
        name: user.name,
        profilePic: user.profilePic,
        twoFaEnabled: user.twoFaEnabled === 1 || user.twoFaEnabled === true,
        autoAnswerEnabled: user.autoAnswerEnabled === 1 || user.autoAnswerEnabled === true,
        autoAnswerMessage: user.autoAnswerMessage || '',
        defaultFontSize: user.defaultFontSize || 12,
        defaultFontFamily: user.defaultFontFamily || 'Arial',
        isDarkMode: user.isDarkMode === 1 || user.isDarkMode === true,
        notificationsEnabled: user.notificationsEnabled === 1 || user.notificationsEnabled === true
      });
    }
  );
});

app.post('/api/profile', authenticate, upload.single('profilePic'), async (req, res) => {
  const { name, password, twoFaEnabled, autoAnswerEnabled, autoAnswerMessage, defaultFontSize, defaultFontFamily, isDarkMode, notificationsEnabled } = req.body;
  const profilePic = req.file ? `/uploads/${req.file.filename}` : null;
  const updates = [];
  const values = [];

  if (name) {
    updates.push('name = ?');
    values.push(name);
  }
  if (password) {
    try {
      const hashedPassword = await bcrypt.hash(password, 10);
      updates.push('password = ?');
      values.push(hashedPassword);
    } catch (e) {
      console.error('Password hash error:', e);
      return res.status(500).json({ error: 'Server error during password hashing' });
    }
  }
  if (profilePic) {
    updates.push('profilePic = ?');
    values.push(profilePic);
  }
  if (twoFaEnabled !== undefined) {
    updates.push('twoFaEnabled = ?');
    values.push(twoFaEnabled === 'true' ? 1 : 0);
  }
  if (autoAnswerEnabled !== undefined) {
    updates.push('autoAnswerEnabled = ?');
    values.push(autoAnswerEnabled === 'true' ? 1 : 0);
  }
  if (autoAnswerMessage !== undefined) {
    updates.push('autoAnswerMessage = ?');
    values.push(autoAnswerMessage || '');
  }
  if (defaultFontSize !== undefined) {
    const size = parseInt(defaultFontSize, 10);
    if (size >= 8 && size <= 36) {
      updates.push('defaultFontSize = ?');
      values.push(size);
    }
  }
  if (defaultFontFamily !== undefined) {
    const validFonts = ['Arial', 'Times New Roman', 'Courier New', 'Helvetica', 'Verdana'];
    if (validFonts.includes(defaultFontFamily)) {
      updates.push('defaultFontFamily = ?');
      values.push(defaultFontFamily);
    }
  }
  if (isDarkMode !== undefined) {
    updates.push('isDarkMode = ?');
    values.push(isDarkMode === 'true' ? 1 : 0);
  }
  if (notificationsEnabled !== undefined) {
    updates.push('notificationsEnabled = ?');
    values.push(notificationsEnabled === 'true' ? 1 : 0);
  }

  if (updates.length === 0) {
    return res.status(400).json({ error: 'No updates provided' });
  }

  values.push(req.user.phone);
  db.run(`UPDATE users SET ${updates.join(', ')} WHERE phone = ?`, values, (err) => {
    if (err) {
      console.error('Profile update error:', err);
      return res.status(400).json({ error: 'Update failed', details: err.message });
    }
    db.get(
      'SELECT phone, name, profilePic, twoFaEnabled, autoAnswerEnabled, autoAnswerMessage, defaultFontSize, defaultFontFamily, isDarkMode, notificationsEnabled FROM users WHERE phone = ?',
      [req.user.phone],
      (err, user) => {
        if (err) {
          console.error('Profile fetch error after update:', err);
          return res.status(500).json({ error: 'Server error' });
        }
        if (!user) return res.status(400).json({ error: 'User not found after update' });
        res.json({
          phone: user.phone,
          name: user.name,
          profilePic: user.profilePic,
          twoFaEnabled: user.twoFaEnabled === 1 || user.twoFaEnabled === true,
          autoAnswerEnabled: user.autoAnswerEnabled === 1 || user.autoAnswerEnabled === true,
          autoAnswerMessage: user.autoAnswerMessage || '',
          defaultFontSize: user.defaultFontSize || 12,
          defaultFontFamily: user.defaultFontFamily || 'Arial',
          isDarkMode: user.isDarkMode === 1 || user.isDarkMode === true,
          notificationsEnabled: user.notificationsEnabled === 1 || user.notificationsEnabled === true
        });
      }
    );
  });
});

// Compose and Send Email with Attachments
app.post('/api/send-email', authenticate, upload.array('attachments', 5), async (req, res) => {
  const { recipientPhone, cc, bcc, subject, body } = req.body;
  const senderPhone = req.user.phone;
  const files = req.files || [];
  const attachments = files.map(file => ({
    filePath: `/uploads/${file.filename}`,
    fileType: file.mimetype,
    originalFileName: encodeURIComponent(file.originalname || 'attachment')
  }));

  if (!recipientPhone || !subject || !body) {
    return res.status(400).json({ error: 'Recipient, subject, and body are required' });
  }

  try {
    db.get('SELECT phone, autoAnswerEnabled, autoAnswerMessage, notificationsEnabled FROM users WHERE phone = ?', [recipientPhone], (err, recipient) => {
      if (err) {
        console.error('Recipient fetch error:', err);
        return res.status(500).json({ error: 'Server error' });
      }
      if (!recipient) {
        return res.status(404).json({ error: 'Recipient not found' });
      }

      const saveEmail = (recPhone, isCcValue = 0, isBccValue = 0) => {
        return new Promise((resolve, reject) => {
          db.run(
            'INSERT INTO emails (senderPhone, recipientPhone, cc, bcc, subject, body, timestamp, isAutoReply, isCc, isBcc) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [senderPhone, recPhone, cc || '', bcc || '', subject, body, new Date().toISOString(), 0, isCcValue, isBccValue],
            function (err) {
              if (err) {
                console.error(`Email save error for ${recPhone}:`, err);
                reject(err);
              } else {
                const emailId = this.lastID;
                if (attachments.length > 0) {
                  const placeholders = attachments.map(() => '(?, ?, ?, ?)').join(', ');
                  const values = attachments.flatMap(a => [emailId, a.filePath, a.fileType, a.originalFileName]);
                  db.run(
                    `INSERT INTO attachments (emailId, filePath, fileType, originalFileName) VALUES ${placeholders}`,
                    values,
                    (err) => {
                      if (err) {
                        console.error(`Attachment save error for ${recPhone}:`, err);
                        reject(err);
                      }
                    }
                  );
                }
                resolve(emailId);
              }
            }
          );
        });
      };

      saveEmail(recipientPhone)
        .then(emailId => {
          const ccNumbers = cc ? cc.split(',').map(num => num.trim()).filter(num => num) : [];
          const bccNumbers = bcc ? bcc.split(',').map(num => num.trim()).filter(num => num) : [];

          const promises = [];
          ccNumbers.forEach(ccNum => {
            if (ccNum !== recipientPhone) {
              promises.push(saveEmail(ccNum, 1, 0));
            }
          });

          bccNumbers.forEach(bccNum => {
            if (bccNum !== recipientPhone && !ccNumbers.includes(bccNum)) {
              promises.push(saveEmail(bccNum, 0, 1));
            }
          });

          return Promise.all(promises).then(() => emailId);
        })
        .then((emailId) => {
          if (recipient.autoAnswerEnabled && recipient.notificationsEnabled && !req.body.isAutoReply) {
            const autoReplySubject = `Re: ${subject}`;
            const autoReplyBody = recipient.autoAnswerMessage || 'Tôi sẽ trả lời bạn sau';
            db.run(
              'INSERT INTO emails (senderPhone, recipientPhone, subject, body, timestamp, isAutoReply) VALUES (?, ?, ?, ?, ?, ?)',
              [recipientPhone, senderPhone, autoReplySubject, autoReplyBody, new Date().toISOString(), 1],
              function (err) {
                if (err) {
                  console.error('Auto reply error:', err);
                } else {
                  console.log(`Auto reply sent from ${recipientPhone} to ${senderPhone}`);
                }
              }
            );
          }

          res.status(200).json({ message: 'Email sent successfully', emailId });
        })
        .catch(err => {
          console.error('Error processing email copies:', err);
          res.status(500).json({ error: 'Failed to process email copies' });
        });
    });
  } catch (e) {
    console.error('Send email exception:', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// Get Emails
app.get('/api/emails', authenticate, (req, res) => {
  const folder = req.query.folder || 'inbox';
  const search = (req.query.search || '').toLowerCase();
  const fromMe = req.query.fromMe === 'true';
  const startDate = req.query.startDate;
  const endDate = req.query.endDate;
  const hasAttachments = req.query.hasAttachments === 'true';
  const labels = req.query.labels ? req.query.labels.split(',') : [];
  const userId = req.user.id;

  console.log('Emails query: folder=%s, search=%s, fromMe=%s, startDate=%s, endDate=%s, hasAttachments=%s, labels=%s, userId=%s',
    folder, search, fromMe, startDate, endDate, hasAttachments, labels, userId);

  let query = '';
  let params = [];
  let conditions = [];

  switch (folder.toLowerCase()) {
    case 'inbox':
      conditions.push('e.recipientPhone = ? AND e.isTrashed = 0');
      params.push(req.user.phone);
      break;
    case 'starred':
      conditions.push('(e.recipientPhone = ? OR e.senderPhone = ? OR e.cc LIKE ? OR e.bcc LIKE ?) AND e.isStarred = 1 AND e.isTrashed = 0');
      params.push(req.user.phone, req.user.phone, `%${req.user.phone}%`, `%${req.user.phone}%`);
      break;
    case 'sent':
      conditions.push('e.senderPhone = ? AND e.isTrashed = 0');
      params.push(req.user.phone);
      break;
    case 'trash':
      conditions.push('(e.recipientPhone = ? OR e.senderPhone = ? OR e.cc LIKE ? OR e.bcc LIKE ?) AND e.isTrashed = 1');
      params.push(req.user.phone, req.user.phone, `%${req.user.phone}%`, `%${req.user.phone}%`);
      break;
    default:
      return res.status(400).json({ error: 'Invalid folder' });
  }

  if (search) {
    conditions.push('(LOWER(e.subject) LIKE ? OR LOWER(e.senderPhone) LIKE ? OR LOWER(e.recipientPhone) LIKE ? OR LOWER(e.body) LIKE ?)');
    params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
  }

  if (fromMe) {
    conditions.push('e.senderPhone = ?');
    params.push(req.user.phone);
  }

  if (startDate && endDate) {
    conditions.push('e.timestamp BETWEEN ? AND ?');
    params.push(startDate, endDate);
  }

  if (hasAttachments) {
    conditions.push('EXISTS (SELECT 1 FROM attachments a WHERE a.emailId = e.id)');
  }

  const executeQuery = () => {
    query = `
      SELECT e.*,
             (SELECT GROUP_CONCAT(a.filePath) FROM attachments a WHERE a.emailId = e.id) as attachmentPaths,
             (SELECT GROUP_CONCAT(a.fileType) FROM attachments a WHERE a.emailId = e.id) as attachmentTypes,
             (SELECT GROUP_CONCAT(a.originalFileName) FROM attachments a WHERE a.emailId = e.id) as attachmentNames,
             (SELECT GROUP_CONCAT(l.label) FROM email_labels el JOIN labels l ON el.labelId = l.id WHERE el.emailId = e.id) as labels
      FROM emails e
      WHERE ${conditions.length ? conditions.join(' AND ') : '1=1'}
      ORDER BY e.timestamp DESC`;

    console.log('Emails SQL query:', query, params);
    db.all(query, params, (err, emails) => {
      if (err) {
        console.error('Database error:', err);
        return res.status(500).json({ error: 'Failed to fetch emails', sqlError: err.message });
      }
      const result = emails.map(email => {
        const attachments = [];
        if (email.attachmentPaths && email.attachmentTypes && email.attachmentNames) {
          const paths = email.attachmentPaths.split(',');
          const types = email.attachmentTypes.split(',');
          const names = email.attachmentNames.split(',');
          for (let i = 0; i < paths.length; i++) {
            attachments.push({
              filePath: paths[i],
              fileType: types[i],
              originalFileName: decodeURIComponent(names[i] || ''),
            });
          }
        }
        return {
          ...email,
          attachments,
          labels: email.labels ? email.labels.split(',') : [],
          attachmentPaths: undefined,
          attachmentTypes: undefined,
          attachmentNames: undefined,
          isRead: email.isRead === 1 || email.isRead === '1',
          isStarred: email.isStarred === 1 || email.isStarred === '1',
          isTrashed: email.isTrashed === 1 || email.isTrashed === '1',
          isAutoReply: email.isAutoReply === 1 || email.isAutoReply === '1',
          isCc: email.isCc === 1 || email.isCc === '1',
          isBcc: email.isBcc === 1 || email.isBcc === '1'
        };
      });
      console.log('Emails response:', result);
      res.json(result);
    });
  };

  if (labels.length > 0) {
    db.all('SELECT id, label FROM labels WHERE userId = ? AND label IN (' + labels.map(() => '?').join(',') + ')', [userId, ...labels], (err, labelRows) => {
      if (err) {
        console.error('Error checking labels:', err);
        return res.status(400).json({ error: 'Failed to fetch emails', sqlError: err.message });
      }
      if (labelRows.length !== labels.length) {
        console.log('Some labels not found for userId', userId, ':', labels, 'Found:', labelRows);
        return res.status(400).json({ error: 'One or more labels not found', missingLabels: labels.filter(l => !labelRows.some(r => r.label === l)) });
      }
      const labelIds = labelRows.map(row => row.id);
      conditions.push(`e.id IN (
        SELECT el.emailId
        FROM email_labels el
        WHERE el.labelId IN (${labelIds.map(() => '?').join(',')})
      )`);
      params.push(...labelIds);
      executeQuery();
    });
  } else {
    executeQuery();
  }
});

// Get Email with Attachments and Labels
app.get('/api/emails/:id', authenticate, (req, res) => {
  const emailId = req.params.id;
  const userId = req.user.id;
  db.get(
    'SELECT * FROM emails WHERE id = ? AND (recipientPhone = ? OR senderPhone = ? OR cc LIKE ? OR bcc LIKE ?)',
    [emailId, req.user.phone, req.user.phone, `%${req.user.phone}%`, `%${req.user.phone}%`],
    (err, email) => {
      if (err) {
        console.error('Email fetch error:', err);
        return res.status(500).json({ error: 'Server error' });
      }
      if (!email) return res.status(404).json({ error: 'Email not found' });
      db.all('SELECT filePath, fileType, originalFileName FROM attachments WHERE emailId = ?', [emailId], (err, attachments) => {
        if (err) {
          console.error('Attachment fetch error:', err);
          return res.status(500).json({ error: 'Failed to fetch attachments' });
        }
        db.all(
          'SELECT l.label FROM email_labels el JOIN labels l ON el.labelId = l.id WHERE el.emailId = ? AND l.userId = ?',
          [emailId, userId],
          (err, labels) => {
            if (err) {
              console.error('Label fetch error:', err);
              return res.status(500).json({ error: 'Failed to fetch labels' });
            }
            email.isRead = email.isRead === 1 || email.isRead === '1';
            email.isStarred = email.isStarred === 1 || email.isStarred === '1';
            email.isTrashed = email.isTrashed === 1 || email.isTrashed === '1';
            email.isAutoReply = email.isAutoReply === 1 || email.isAutoReply === '1';
            email.isCc = email.isCc === 1 || email.isCc === '1';
            email.isBcc = email.isBcc === 1 || email.isBcc === '1';
            email.attachments = attachments.map(attachment => ({
              ...attachment,
              originalFileName: decodeURIComponent(attachment.originalFileName || ''),
            }));
            email.labels = labels.map(label => label.label);
            res.json(email);
          }
        );
      });
    }
  );
});

// Get Draft by ID
app.get('/api/drafts/:id', authenticate, (req, res) => {
  const draftId = req.params.id;
  db.get(
    'SELECT * FROM drafts WHERE id = ? AND senderPhone = ?',
    [draftId, req.user.phone],
    (err, draft) => {
      if (err) {
        console.error('Draft fetch error:', err);
        return res.status(500).json({ error: 'Server error', details: err.message });
      }
      if (!draft) return res.status(404).json({ error: 'Draft not found' });
      res.json({
        id: draft.id,
        senderPhone: draft.senderPhone,
        recipientPhone: draft.recipientPhone || '',
        cc: draft.cc || '',
        bcc: draft.bcc || '',
        subject: draft.subject || '',
        body: draft.body || '',
        attachment: draft.attachment || '',
        timestamp: draft.timestamp,
      });
    }
  );
});

// Assign/Remove Labels
app.post('/api/email-labels', authenticate, (req, res) => {
  const { emailId, label, value } = req.body;
  const userId = req.user.id;
  if (!emailId || !label || value === undefined) {
    return res.status(400).json({ error: 'emailId, label, and value are required' });
  }

  db.get(
    'SELECT id FROM emails WHERE id = ? AND (recipientPhone = ? OR senderPhone = ? OR cc LIKE ? OR bcc LIKE ?)',
    [emailId, req.user.phone, req.user.phone, `%${req.user.phone}%`, `%${req.user.phone}%`],
    (err, email) => {
      if (err) {
        console.error('Email check error:', err);
        return res.status(500).json({ error: 'Server error' });
      }
      if (!email) {
        return res.status(404).json({ error: 'Email not found or unauthorized' });
      }

      db.get('SELECT id FROM labels WHERE label = ? AND userId = ?', [label, userId], (err, labelRow) => {
        if (err) {
          console.error('Label fetch error:', err);
          return res.status(500).json({ error: 'Server error' });
        }
        if (!labelRow) {
          return res.status(404).json({ error: 'Label not found' });
        }
        const labelId = labelRow.id;

        if (value) {
          db.run(
            'INSERT OR IGNORE INTO email_labels (emailId, labelId) VALUES (?, ?)',
            [emailId, labelId],
            function(err) {
              if (err) {
                console.error('Insert label error:', err);
                return res.status(500).json({ error: 'Failed to assign label' });
              }
              res.status(200).json({ success: true });
            }
          );
        } else {
          db.run(
            'DELETE FROM email_labels WHERE emailId = ? AND labelId = ?',
            [emailId, labelId],
            function(err) {
              if (err) {
                console.error('Delete label error:', err);
                return res.status(500).json({ error: 'Failed to remove label' });
              }
              res.status(200).json({ success: true });
            }
          );
        }
      });
    }
  );
});

// Serve file for download with original file name
app.get('/api/download/:filePath', authenticate, (req, res) => {
  const filePath = decodeURIComponent(req.params.filePath);
  const fullPath = path.join(__dirname, 'uploads', filePath.split('/').pop());
  db.get('SELECT originalFileName FROM attachments WHERE filePath = ?', [filePath], (err, attachment) => {
    if (err) {
      console.error('Attachment fetch error:', err);
      return res.status(500).json({ error: 'Server error' });
    }
    if (!attachment) return res.status(404).json({ error: 'File not found' });
    res.setHeader('Content-Disposition', `attachment; filename="${decodeURIComponent(attachment.originalFileName)}"`);
    res.sendFile(fullPath, (err) => {
      if (err) {
        console.error('File send error:', err);
        res.status(500).json({ error: 'Failed to send file' });
      }
    });
  });
});

// Save Draft
app.post('/api/save-draft', authenticate, upload.single('attachment'), async (req, res) => {
  const { recipientPhone, cc, bcc, subject, body } = req.body;
  console.log('Received draft data:', { recipientPhone, cc, bcc, subject, body });
  const attachment = req.file ? `/uploads/${req.file.filename}` : null;
  const attachmentName = req.file ? encodeURIComponent(req.file.originalname || 'attachment') : null;
  if (!recipientPhone && !subject && !body) {
    return res.status(400).json({ error: 'At least one field is required for a draft' });
  }
  try {
    const cleanedBody = body || '';
    db.run(
      'INSERT INTO drafts (senderPhone, recipientPhone, cc, bcc, subject, body, attachment) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [req.user.phone, recipientPhone || '', cc || '', bcc || '', subject || '', cleanedBody, attachment],
      function (err) {
        if (err) {
          console.error('Database error saving draft:', err);
          return res.status(400).json({ error: 'Failed to save draft' });
        }
        res.json({
          message: 'Draft saved',
          draftId: this.lastID,
          attachmentName: attachmentName ? decodeURIComponent(attachmentName) : null
        });
      }
    );
  } catch (e) {
    console.error('Save draft exception:', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// Get Drafts
app.get('/api/drafts', authenticate, (req, res) => {
  const search = (req.query.search || '').toLowerCase();
  const startDate = req.query.startDate;
  const endDate = req.query.endDate;
  const hasAttachments = req.query.hasAttachments === 'true';
  const labels = req.query.labels ? req.query.labels.split(',') : [];

  console.log('Drafts query: search=%s, startDate=%s, endDate=%s, hasAttachments=%s, labels=%s',
    search, startDate, endDate, hasAttachments, labels);

  let conditions = ['senderPhone = ?'];
  let params = [req.user.phone];

  if (search) {
    conditions.push('(LOWER(subject) LIKE ? OR LOWER(recipientPhone) LIKE ? OR LOWER(body) LIKE ?)');
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }

  if (startDate && endDate) {
    conditions.push('timestamp BETWEEN ? AND ?');
    params.push(startDate, endDate);
  }

  if (hasAttachments) {
    conditions.push('attachment IS NOT NULL AND attachment != ""');
  }

  if (labels.length > 0) {
    // Skip as drafts do not support labels
  }

  let query = `
    SELECT id, senderPhone, recipientPhone, cc, bcc, subject, body, attachment, timestamp
    FROM drafts
    WHERE ${conditions.join(' AND ')}
    ORDER BY timestamp DESC
  `;

  console.log('Drafts SQL query:', query);
  console.log('Query params:', params);

  db.all(query, params, (err, drafts) => {
    if (err) {
      console.error('Drafts query error:', err);
      return res.status(400).json({ error: 'Failed to fetch drafts', details: err.message });
    }
    const result = drafts.map(draft => ({
      id: draft.id,
      senderPhone: draft.senderPhone,
      recipientPhone: draft.recipientPhone || '',
      cc: draft.cc || '',
      bcc: draft.bcc || '',
      subject: draft.subject || '',
      body: draft.body || '',
      attachment: draft.attachment || '',
      timestamp: draft.timestamp,
    }));
    console.log('Drafts response:', result);
    res.json(result);
  });
});

// Update Draft Action
app.post('/api/update-draft-action', authenticate, (req, res) => {
  return res.status(400).json({ error: 'Drafts do not support actions like read' });
});

// Delete Draft
app.delete('/api/delete-draft/:id', authenticate, (req, res) => {
  const draftId = req.params.id;
  db.get('SELECT * FROM drafts WHERE id = ? AND senderPhone = ?', [draftId, req.user.phone], (err, draft) => {
    if (err) {
      console.error('Draft fetch error:', err);
      return res.status(500).json({ error: 'Server error' });
    }
    if (!draft) {
      return res.status(404).json({ error: 'Draft not found or unauthorized' });
    }
    db.run('DELETE FROM drafts WHERE id = ?', [draftId], function (err) {
      if (err) {
        console.error('Delete draft error:', err);
        return res.status(400).json({ error: 'Failed to delete draft' });
      }
      res.json({ message: 'Draft deleted' });
    });
  });
});

// Update Email Actions
app.post('/api/email-actions', authenticate, (req, res) => {
  const { emailId, action, value } = req.body;
  if (!emailId || !action || value === undefined) {
    return res.status(400).json({ error: 'emailId, action, and value are required' });
  }

  db.get(
    'SELECT id FROM emails WHERE id = ? AND (recipientPhone = ? OR senderPhone = ? OR cc LIKE ? OR bcc LIKE ?)',
    [emailId, req.user.phone, req.user.phone, `%${req.user.phone}%`, `%${req.user.phone}%`],
    (err, email) => {
      if (err) {
        console.error('Email check error:', err);
        return res.status(500).json({ error: 'Server error' });
      }
      if (!email) {
        return res.status(404).json({ error: 'Email not found or unauthorized' });
      }

      let updateQuery;
      let params = [value ? 1 : 0, emailId];

      switch (action.toLowerCase()) {
        case 'read':
          updateQuery = 'UPDATE emails SET isRead = ? WHERE id = ?';
          break;
        case 'star':
          updateQuery = 'UPDATE emails SET isStarred = ? WHERE id = ?';
          break;
        case 'trash':
          updateQuery = 'UPDATE emails SET isTrashed = ? WHERE id = ?';
          break;
        default:
          return res.status(400).json({ error: 'Invalid action' });
      }

      db.run(updateQuery, params, (err) => {
        if (err) {
          console.error('Update action error:', err);
          return res.status(400).json({ error: `Failed to update ${action}` });
        }
        res.status(200).json({ success: true });
      });
    }
  );
});

// Get Available Labels
app.get('/api/labels', authenticate, (req, res) => {
  db.all(
    'SELECT label FROM labels WHERE userId = (SELECT id FROM users WHERE phone = ?)',
    [req.user.phone],
    (err, rows) => {
      if (err) {
        console.error('Fetch labels error:', err);
        return res.status(500).json({ error: 'Failed to fetch labels', details: err.message });
      }
      const labels = rows.map(row => row.label);
      res.json(labels);
    }
  );
});

// Add or Remove Label
app.post('/api/labels', authenticate, async (req, res) => {
  const { label, value } = req.body;
  const userId = req.user.id;

  try {
    if (!label || typeof label !== 'string' || label.trim() === '') {
      return res.status(400).json({ error: 'Label is required and must be a non-empty string' });
    }

    if (value === true) {
      db.run(
        'INSERT INTO labels (userId, label) VALUES (?, ?)',
        [userId, label.trim()],
        function (err) {
          if (err) {
            console.error('Insert label error:', err);
            if (err.code === 'SQLITE_CONSTRAINT') {
              return res.status(409).json({ error: 'Label already exists' });
            }
            return res.status(500).json({ error: 'Failed to add label' });
          }
          res.status(200).json({ success: true, message: 'Label added successfully', label: label.trim() });
        }
      );
    } else if (value === false) {
      db.run(
        'DELETE FROM labels WHERE userId = ? AND label = ?',
        [userId, label.trim()],
        function (err) {
          if (err) {
            console.error('Delete label error:', err);
            return res.status(500).json({ error: 'Failed to delete label' });
          }
          if (this.changes === 0) {
            return res.status(404).json({ error: 'Label not found' });
          }
          res.status(200).json({ success: true, message: 'Label deleted successfully' });
        }
      );
    } else {
      res.status(400).json({ error: 'Invalid value. Use true to add or false to delete' });
    }
  } catch (e) {
    console.error('Label operation exception:', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// Edit Label
app.put('/api/labels', authenticate, (req, res) => {
  const { oldLabel, newLabel } = req.body;
  if (!oldLabel || !newLabel) {
    return res.status(400).json({ error: 'oldLabel and newLabel are required' });
  }

  const userId = req.user.id;
  console.log(`PUT /api/labels - userId: ${userId}, oldLabel: ${oldLabel}, newLabel: ${newLabel}`);

  db.serialize(() => {
    db.get(
      'SELECT id FROM labels WHERE userId = ? AND label = ?',
      [userId, oldLabel],
      (err, label) => {
        if (err) {
          console.error('Label fetch error:', err);
          return res.status(500).json({ error: 'Server error', details: err.message });
        }
        if (!label) {
          console.error('Label not found - userId:', userId, 'oldLabel:', oldLabel);
          return res.status(404).json({ error: 'Label not found' });
        }

        const labelId = label.id;

        db.run(
          'UPDATE labels SET label = ? WHERE id = ? AND userId = ?',
          [newLabel, labelId, userId],
          function (err) {
            if (err) {
              console.error('Update label error:', err);
              return res.status(500).json({ error: 'Failed to update label', details: err.message });
            }
            res.json({ success: true, message: 'Label updated successfully', newLabel: newLabel });
          }
        );
      }
    );
  });
});

// Serve static files
app.use('/uploads', express.static('uploads'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});