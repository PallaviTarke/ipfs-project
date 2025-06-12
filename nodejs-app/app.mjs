import express from 'express';
import multer from 'multer';
import { create } from 'ipfs-http-client';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const upload = multer({ dest: 'uploads/' });

// Connect to local IPFS daemon
const ipfs = create({ url: 'http://127.0.0.1:5001' });

// Shared Azure Files path
const cidFilePath = '/mnt/ipfs_share/ipfs_cids.txt';

app.post('/upload', upload.single('file'), async (req, res) => {
  try {
    const filePath = path.join(__dirname, req.file.path);
    const file = fs.readFileSync(filePath);

    // Add file to IPFS
    const result = await ipfs.add(file);
    const cid = result.cid.toString();
    const originalFileName = req.file.originalname;

    // Append filename and CID to shared Azure Files log file
    fs.appendFileSync(cidFilePath, `${originalFileName}: ${cid}\n`);

    // Clean up temp upload
    fs.unlinkSync(filePath);

    res.json({ filename: originalFileName, cid });
  } catch (err) {
    console.error('Upload error:', err);
    res.status(500).json({ error: 'File upload failed' });
  }
});

app.get('/', (req, res) => {
  res.send(`
    <h2>Upload File to IPFS</h2>
    <form method="POST" enctype="multipart/form-data" action="/upload">
      <input type="file" name="file" required />
      <button type="submit">Upload</button>
    </form>
  `);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`App running at http://localhost:${PORT}`);
});