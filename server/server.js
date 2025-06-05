const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const multer = require('multer');
const path = require('path');
const cors = require('cors');
const fs = require('fs');

const app = express();
app.use(cors());
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
    cb(null, uniqueSuffix + path.extname(file.originalname));
  },
});

const upload = multer({ storage: storage });

const db = new sqlite3.Database('email.db', (err) => {
  if (err) console.error(err);
  console.log('Connected to SQLite database');
});

// Database schema creation
db.run(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT UNIQUE,
    password TEXT,
    name TEXT,
    profilePic TEXT,
    twoFaEnabled BOOLEAN DEFAULT 0
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
    isTrashed BOOLEAN DEFAULT 0
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
  CREATE TABLE IF NOT EXISTS email_labels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    emailId INTEGER,
    label TEXT,
    FOREIGN KEY (emailId) REFERENCES emails(id),
    UNIQUE(emailId, label)
  )
`);

const SECRET_KEY = '8d82733305f00766889c5182cce274f06190bfbafc267659c65d7bce60034bdc3dc9cb497d16d0f3f0e5249f42a089dcb93704ec50aa184dfc0863d2f2ce9156';

// Middleware to verify JWT
const authenticate = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token provided' });
  try {
    const decoded = jwt.verify(token, SECRET_KEY);
    req.user = decoded;
    next();
  } catch (err) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Registration
app.post('/api/register', upload.single('profilePic'), async (req, res) => {
  const { phone, password, name } = req.body;
  const profilePic = req.file ? `/uploads/${req.file.filename}` : null;
  const hashedPassword = await bcrypt.hash(password, 10);
  db.run(
    'INSERT INTO users (phone, password, name, profilePic, twoFaEnabled) VALUES (?, ?, ?, ?, ?)',
    [phone, hashedPassword, name, profilePic, false],
    (err) => {
      if (err) return res.status(400).json({ error: 'Phone number already exists' });
      res.status(201).json({ message: 'User registered' });
    }
  );
});

// Login
app.post('/api/login', async (req, res) => {
  const { phone, password } = req.body;
  db.get('SELECT * FROM users WHERE phone = ?', [phone], async (err, user) => {
    if (err || !user) return res.status(400).json({ error: 'User not found' });
    const valid = await bcrypt.compare(password, user.password);
    if (!valid) return res.status(400).json({ error: 'Invalid password' });
    const token = jwt.sign({ phone: user.phone, id: user.id }, SECRET_KEY, { expiresIn: '1h' });
    res.json({ token, twoFaEnabled: user.twoFaEnabled });
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
  db.get('SELECT phone, name, profilePic, twoFaEnabled FROM users WHERE phone = ?', [req.user.phone], (err, user) => {
    if (err || !user) return res.status(400).json({ error: 'User not found' });
    res.json(user);
  });
});

app.post('/api/profile', authenticate, upload.single('profilePic'), async (req, res) => {
  const { name, password, twoFaEnabled } = req.body;
  const profilePic = req.file ? `/uploads/${req.file.filename}` : null;
  const updates = [];
  const values = [];
  if (name) {
    updates.push('name = ?');
    values.push(name);
  }
  if (password) {
    const hashedPassword = await bcrypt.hash(password, 10);
    updates.push('password = ?');
    values.push(hashedPassword);
  }
  if (profilePic) {
    updates.push('profilePic = ?');
    values.push(profilePic);
  }
  if (twoFaEnabled !== undefined) {
    updates.push('twoFaEnabled = ?');
    values.push(twoFaEnabled === 'true' ? 1 : 0);
  }
  if (updates.length === 0) {
    return res.status(400).json({ error: 'No updates provided' });
  }
  values.push(req.user.phone);
  db.run(`UPDATE users SET ${updates.join(', ')} WHERE phone = ?`, values, (err) => {
    if (err) {
      console.error('Profile update error:', err);
      return res.status(400).json({ error: 'Update failed' });
    }
    db.get('SELECT phone, name, profilePic, twoFaEnabled FROM users WHERE phone = ?', [req.user.phone], (err, user) => {
      if (err || !user) return res.status(400).json({ error: 'User not found after update' });
      res.json(user);
    });
  });
});

// Compose and Send Email with Attachments
app.post('/api/send-email', authenticate, upload.array('attachments', 5), async (req, res) => {
  const { recipientPhone, cc, bcc, subject, body } = req.body;
  const attachments = req.files || [];
  if (!recipientPhone || !subject || !body) {
    return res.status(400).json({ error: 'Recipient, subject, and body are required' });
  }
  try {
    db.get('SELECT id FROM users WHERE phone = ?', [recipientPhone], (err, user) => {
      if (err || !user) {
        return res.status(400).json({ error: 'Recipient phone number not found' });
      }
      db.run(
        'INSERT INTO emails (senderPhone, recipientPhone, cc, bcc, subject, body) VALUES (?, ?, ?, ?, ?, ?)',
        [req.user.phone, recipientPhone, cc || '', bcc || '', subject, body],
        function (err) {
          if (err) {
            console.error('Database error:', err);
            return res.status(400).json({ error: 'Failed to send email' });
          }
          const emailId = this.lastID;
          if (attachments.length > 0) {
            const attachmentData = attachments.map(file => ({
              emailId,
              filePath: `/uploads/${file.filename}`,
              fileType: file.mimetype,
              originalFileName: encodeURIComponent(file.originalname),
            }));
            db.run(
              `INSERT INTO attachments (emailId, filePath, fileType, originalFileName) VALUES ${attachmentData.map(() => '(?, ?, ?, ?)').join(',')}`,
              attachmentData.flatMap(a => [a.emailId, a.filePath, a.fileType, a.originalFileName]),
              (err) => {
                if (err) {
                  console.error('Attachment insertion error:', err);
                  return res.status(400).json({ error: 'Failed to save attachments' });
                }
                res.json({ message: 'Email sent', emailId });
              }
            );
          } else {
            res.json({ message: 'Email sent', emailId });
          }
        }
      );
    });
  } catch (e) {
    console.error('Send email exception:', e);
    res.status(500).json({ error: 'Server error' });
  }
});
// này là code cũ nha ae, mốt xóa cũng đc
// Get Emails
// app.get('/api/emails', authenticate, (req, res) => {
//   const folder = req.query.folder || 'inbox';
//   const search = (req.query.search || '').toLowerCase(); // Chuyển về chữ thường
//   console.log('Emails query: folder=%s, search=%s', folder, search);
//   let query = '';
//   let params = [];

//   switch (folder.toLowerCase()) {
//     case 'inbox':
//       query = `
//         SELECT e.*, 
//                (SELECT GROUP_CONCAT(a.filePath) FROM attachments a WHERE a.emailId = e.id) as attachmentPaths,
//                (SELECT GROUP_CONCAT(a.fileType) FROM attachments a WHERE a.emailId = e.id) as attachmentTypes,
//                (SELECT GROUP_CONCAT(a.originalFileName) FROM attachments a WHERE a.emailId = e.id) as attachmentNames,
//                (SELECT GROUP_CONCAT(el.label) FROM email_labels el WHERE el.emailId = e.id) as labels
//         FROM emails e 
//         WHERE e.recipientPhone = ? 
//           AND e.isTrashed = 0
//           ${search ? 'AND (LOWER(e.subject) LIKE ? OR LOWER(e.senderPhone) LIKE ? OR LOWER(e.recipientPhone) LIKE ? OR LOWER(e.body) LIKE ?)' : ''}
//         ORDER BY e.timestamp DESC`;
//       params = [req.user.phone];
//       if (search) params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
//       break;
//     case 'starred':
//       query = `
//         SELECT e.*, 
//                (SELECT GROUP_CONCAT(a.filePath) FROM attachments a WHERE a.emailId = e.id) as attachmentPaths,
//                (SELECT GROUP_CONCAT(a.fileType) FROM attachments a WHERE a.emailId = e.id) as attachmentTypes,
//                (SELECT GROUP_CONCAT(a.originalFileName) FROM attachments a WHERE a.emailId = e.id) as attachmentNames,
//                (SELECT GROUP_CONCAT(el.label) FROM email_labels el WHERE el.emailId = e.id) as labels
//         FROM emails e 
//         WHERE (e.recipientPhone = ? OR e.senderPhone = ? OR e.cc LIKE '%' || ? || '%' OR e.bcc LIKE '%' || ? || '%') 
//           AND e.isStarred = 1 
//           AND e.isTrashed = 0
//           ${search ? 'AND (LOWER(e.subject) LIKE ? OR LOWER(e.senderPhone) LIKE ? OR LOWER(e.recipientPhone) LIKE ? OR LOWER(e.body) LIKE ?)' : ''}
//         ORDER BY e.timestamp DESC`;
//       params = [req.user.phone, req.user.phone, req.user.phone, req.user.phone];
//       if (search) params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
//       break;
//     case 'sent':
//       query = `
//         SELECT e.*, 
//                (SELECT GROUP_CONCAT(a.filePath) FROM attachments a WHERE a.emailId = e.id) as attachmentPaths,
//                (SELECT GROUP_CONCAT(a.fileType) FROM attachments a WHERE a.emailId = e.id) as attachmentTypes,
//                (SELECT GROUP_CONCAT(a.originalFileName) FROM attachments a WHERE a.emailId = e.id) as attachmentNames,
//                (SELECT GROUP_CONCAT(el.label) FROM email_labels el WHERE el.emailId = e.id) as labels
//         FROM emails e 
//         WHERE e.senderPhone = ?
//           AND e.isTrashed = 0
//           ${search ? 'AND (LOWER(e.subject) LIKE ? OR LOWER(e.senderPhone) LIKE ? OR LOWER(e.recipientPhone) LIKE ? OR LOWER(e.body) LIKE ?)' : ''}
//         ORDER BY e.timestamp DESC`;
//       params = [req.user.phone];
//       if (search) params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
//       break;
//     case 'trash':
//       query = `
//         SELECT e.*, 
//                (SELECT GROUP_CONCAT(a.filePath) FROM attachments a WHERE a.emailId = e.id) as attachmentPaths,
//                (SELECT GROUP_CONCAT(a.fileType) FROM attachments a WHERE a.emailId = e.id) as attachmentTypes,
//                (SELECT GROUP_CONCAT(a.originalFileName) FROM attachments a WHERE a.emailId = e.id) as attachmentNames,
//                (SELECT GROUP_CONCAT(el.label) FROM email_labels el WHERE el.emailId = e.id) as labels
//         FROM emails e 
//         WHERE (e.recipientPhone = ? OR e.senderPhone = ? OR e.cc LIKE '%' || ? || '%' OR e.bcc LIKE '%' || ? || '%') 
//           AND e.isTrashed = 1
//           ${search ? 'AND (LOWER(e.subject) LIKE ? OR LOWER(e.senderPhone) LIKE ? OR LOWER(e.recipientPhone) LIKE ? OR LOWER(e.body) LIKE ?)' : ''}
//         ORDER BY e.timestamp DESC`;
//       params = [req.user.phone, req.user.phone, req.user.phone, req.user.phone];
//       if (search) params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
//       break;
//     default:
//       return res.status(400).json({ error: 'Invalid folder' });
//   }

//   console.log('Emails SQL query:', query, params);
//   db.all(query, params, (err, emails) => {
//     if (err) {
//       console.error('Database error:', err);
//       return res.status(400).json({ error: 'Failed to fetch emails' });
//     }
//     const result = emails.map(email => {
//       const attachments = [];
//       if (email.attachmentPaths && email.attachmentTypes && email.attachmentNames) {
//         const paths = email.attachmentPaths.split(',');
//         const types = email.attachmentTypes.split(',');
//         const names = email.attachmentNames.split(',');
//         for (let i = 0; i < paths.length; i++) {
//           attachments.push({
//             filePath: paths[i],
//             fileType: types[i],
//             originalFileName: decodeURIComponent(names[i] || ''),
//           });
//         }
//       }
//       return {
//         ...email,
//         attachments,
//         labels: email.labels ? email.labels.split(',') : [],
//         attachmentPaths: undefined,
//         attachmentTypes: undefined,
//         attachmentNames: undefined,
//         isRead: email.isRead === 1 || email.isRead === '1',
//         isStarred: email.isStarred === 1 || email.isStarred === '1',
//         isTrashed: email.isTrashed === 1 || email.isTrashed === '1',
//       };
//     });
//     console.log('Emails response:', result);
//     res.json(result);
//   });
// });

app.get('/api/emails', authenticate, (req, res) => {
  const folder = req.query.folder || 'inbox';
  const search = (req.query.search || '').toLowerCase();
  const fromMe = req.query.fromMe === 'true';
  const startDate = req.query.startDate;
  const endDate = req.query.endDate;
  const hasAttachments = req.query.hasAttachments === 'true';

  console.log('Emails query: folder=%s, search=%s, fromMe=%s, startDate=%s, endDate=%s, hasAttachments=%s', 
    folder, search, fromMe, startDate, endDate, hasAttachments);

  let query = '';
  let params = [];
  let conditions = [];

  // Base query based on folder
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

  // Add search condition
  if (search) {
    conditions.push('(LOWER(e.subject) LIKE ? OR LOWER(e.senderPhone) LIKE ? OR LOWER(e.recipientPhone) LIKE ? OR LOWER(e.body) LIKE ?)');
    params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
  }

  // Add "From me" condition
  if (fromMe) {
    conditions.push('e.senderPhone = ?');
    params.push(req.user.phone);
  }

  // Add date range condition
  if (startDate && endDate) {
    conditions.push('e.timestamp BETWEEN ? AND ?');
    params.push(startDate, endDate);
  }

  // Add hasAttachments condition
  if (hasAttachments) {
    conditions.push('EXISTS (SELECT 1 FROM attachments a WHERE a.emailId = e.id)');
  }

  query = `
    SELECT e.*, 
           (SELECT GROUP_CONCAT(a.filePath) FROM attachments a WHERE a.emailId = e.id) as attachmentPaths,
           (SELECT GROUP_CONCAT(a.fileType) FROM attachments a WHERE a.emailId = e.id) as attachmentTypes,
           (SELECT GROUP_CONCAT(a.originalFileName) FROM attachments a WHERE a.emailId = e.id) as attachmentNames,
           (SELECT GROUP_CONCAT(el.label) FROM email_labels el WHERE el.emailId = e.id) as labels
    FROM emails e 
    WHERE ${conditions.join(' AND ')}
    ORDER BY e.timestamp DESC`;

  console.log('Emails SQL query:', query, params);
  db.all(query, params, (err, emails) => {
    if (err) {
      console.error('Database error:', err);
      return res.status(400).json({ error: 'Failed to fetch emails' });
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
      };
    });
    console.log('Emails response:', result);
    res.json(result);
  });
});

// Get Email with Attachments and Labels
app.get('/api/emails/:id', authenticate, (req, res) => {
  const emailId = req.params.id;
  db.get(
    'SELECT * FROM emails WHERE id = ? AND (recipientPhone = ? OR senderPhone = ? OR cc LIKE ? OR bcc LIKE ?)',
    [emailId, req.user.phone, req.user.phone, `%${req.user.phone}%`, `%${req.user.phone}%`],
    (err, email) => {
      if (err || !email) return res.status(404).json({ error: 'Email not found' });
      db.all('SELECT filePath, fileType, originalFileName FROM attachments WHERE emailId = ?', [emailId], (err, attachments) => {
        if (err) return res.status(400).json({ error: 'Failed to fetch attachments' });
        db.all('SELECT label FROM email_labels WHERE emailId = ?', [emailId], (err, labels) => {
          if (err) return res.status(400).json({ error: 'Failed to fetch labels' });
          email.isRead = email.isRead === 1 || email.isRead === '1';
          email.isStarred = email.isStarred === 1 || email.isStarred === '1';
          email.isTrashed = email.isTrashed === 1 || email.isTrashed === '1';
          email.attachments = attachments.map(attachment => ({
            ...attachment,
            originalFileName: decodeURIComponent(attachment.originalFileName || ''),
          }));
          email.labels = labels.map(label => label.label);
          res.json(email);
        });
      });
    }
  );
});

// Assign/Remove Labels
app.post('/api/email-labels', authenticate, (req, res) => {
  const { emailId, label, value } = req.body;
  if (!emailId || !label || value === undefined) {
    return res.status(400).json({ error: 'emailId, label, and value are required' });
  }

  db.get(
    'SELECT id FROM emails WHERE id = ? AND (recipientPhone = ? OR senderPhone = ? OR cc LIKE ? OR bcc LIKE ?)',
    [emailId, req.user.phone, req.user.phone, `%${req.user.phone}%`, `%${req.user.phone}%`],
    (err, email) => {
      if (err || !email) {
        return res.status(404).json({ error: 'Email not found or unauthorized' });
      }

      if (value) {
        db.run(
          'INSERT OR IGNORE INTO email_labels (emailId, label) VALUES (?, ?)',
          [emailId, label],
          function (err) {
            if (err) {
              console.error('Insert label error:', err);
              return res.status(500).json({ error: 'Failed to assign label' });
            }
            res.status(200).json({ success: true });
          }
        );
      } else {
        db.run(
          'DELETE FROM email_labels WHERE emailId = ? AND label = ?',
          [emailId, label],
          function (err) {
            if (err) {
              console.error('Delete label error:', err);
              return res.status(500).json({ error: 'Failed to remove label' });
            }
            res.status(200).json({ success: true });
          }
        );
      }
    }
  );
});

// Serve file for download with original file name
app.get('/api/download/:filePath', authenticate, (req, res) => {
  const filePath = decodeURIComponent(req.params.filePath);
  const fullPath = path.join(__dirname, 'uploads', filePath.split('/').pop());
  db.get('SELECT originalFileName FROM attachments WHERE filePath = ?', [filePath], (err, attachment) => {
    if (err || !attachment) return res.status(404).json({ error: 'File not found' });
    res.setHeader('Content-Disposition', `attachment; filename="${decodeURIComponent(attachment.originalFileName)}"`);
    res.sendFile(fullPath);
  });
});

// Save Draft
app.post('/api/save-draft', authenticate, upload.single('attachment'), async (req, res) => {
  const { recipientPhone, cc, bcc, subject, body } = req.body;
  console.log('Received draft data:', { recipientPhone, cc, bcc, subject, body });
  const attachment = req.file ? `/uploads/${req.file.filename}` : null;
  const attachmentName = req.file ? encodeURIComponent(req.file.originalname) : null;
  if (!recipientPhone && !subject && !body) {
    return res.status(400).json({ error: 'At least one field is required for a draft' });
  }
  try {
    let cleanedBody = body || '{}';
    try {
      JSON.parse(cleanedBody);
    } catch (e) {
      console.error('Invalid JSON in body from client, using default:', e);
      cleanedBody = JSON.stringify([{ insert: body }]);
    }

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
// Get Drafts
// app.get('/api/drafts', authenticate, (req, res) => {
//   const search = (req.query.search || '').toLowerCase();
//   console.log('Drafts query: search=%s', search);
//   let query = `
//     SELECT * FROM drafts 
//     WHERE senderPhone = ?
//       ${search ? 'AND (LOWER(subject) LIKE ? OR LOWER(recipientPhone) LIKE ? OR LOWER(body) LIKE ?)' : ''}
//     ORDER BY timestamp DESC
//   `;
//   let params = [req.user.phone];
//   if (search) params.push(`%${search}%`, `%${search}%`, `%${search}%`);
//   console.log('Drafts SQL query:', query, params);
//   db.all(query, params, (err, drafts) => {
//     if (err) {
//       console.error('Database error:', err);
//       return res.status(400).json({ error: 'Failed to fetch drafts' });
//     }
//     const result = drafts.map(draft => ({
//       ...draft,
//     }));
//     console.log('Drafts response:', result);
//     res.json(result);
//   });
// });

app.get('/api/drafts', authenticate, (req, res) => {
  const search = (req.query.search || '').toLowerCase();
  const startDate = req.query.startDate;
  const endDate = req.query.endDate;
  const hasAttachments = req.query.hasAttachments === 'true';

  console.log('Drafts query: search=%s, startDate=%s, endDate=%s, hasAttachments=%s', 
    search, startDate, endDate, hasAttachments);

  let conditions = ['senderPhone = ?'];
  let params = [req.user.phone];

  // Add search condition
  if (search) {
    conditions.push('(LOWER(subject) LIKE ? OR LOWER(recipientPhone) LIKE ? OR LOWER(body) LIKE ?)');
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }

  // Add date range condition
  if (startDate && endDate) {
    conditions.push('timestamp BETWEEN ? AND ?');
    params.push(startDate, endDate);
  }

  // Add hasAttachments condition
  if (hasAttachments) {
    conditions.push('attachment IS NOT NULL AND attachment != ""');
  }

  let query = `
    SELECT * FROM drafts 
    WHERE ${conditions.join(' AND ')}
    ORDER BY timestamp DESC
  `;

  console.log('Drafts SQL query:', query, params);
  db.all(query, params, (err, drafts) => {
    if (err) {
      console.error('Database error:', err);
      return res.status(400).json({ error: 'Failed to fetch drafts' });
    }
    const result = drafts.map(draft => ({
      ...draft,
    }));
    console.log('Drafts response:', result);
    res.json(result);
  });
});

// Update Draft Action (Loại bỏ vì drafts không có cột isRead)
app.post('/api/update-draft-action', authenticate, (req, res) => {
  return res.status(400).json({ error: 'Drafts do not support actions like read' });
});

// Delete Draft
app.delete('/api/delete-draft/:id', authenticate, (req, res) => {
  const draftId = req.params.id;
  db.get('SELECT * FROM drafts WHERE id = ? AND senderPhone = ?', [draftId, req.user.phone], (err, draft) => {
    if (err || !draft) {
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
  if (!emailId || !action) return res.status(400).json({ error: 'Email ID and action are required' });
  const updates = {
    'read': 'isRead = ?',
    'star': 'isStarred = ?',
    'trash': 'isTrashed = ?',
  }[action];
  if (!updates) return res.status(400).json({ error: 'Invalid action' });

  db.run(
    `UPDATE emails SET ${updates} WHERE id = ? AND (recipientPhone = ? OR senderPhone = ? OR cc LIKE ? OR bcc LIKE ?)`,
    [value ? 1 : 0, emailId, req.user.phone, req.user.phone, `%${req.user.phone}%`, `%${req.user.phone}%`],
    function (err) {
      if (err) {
        console.error('Database update error:', err);
        return res.status(400).json({ error: 'Failed to update email action' });
      }
      if (this.changes === 0) {
        console.log(`No email updated for emailId ${emailId}, user ${req.user.phone}`);
        return res.status(404).json({ error: 'Email not found or unauthorized' });
      }
      console.log(`Updated email ${emailId} with action ${action} to ${value}`);
      res.json({ message: 'Action updated' });
    }
  );
});

// Serve files
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.listen(3000, () => console.log('Server running on port 3000'));