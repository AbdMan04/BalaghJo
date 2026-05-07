const multer = require('multer');
const path = require('path');
const fs = require('fs');

const uploadDir = path.resolve(process.env.UPLOAD_DIR || 'uploads');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const safe = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}${ext}`;
    cb(null, safe);
  },
});

const IMAGE_EXTS = /\.(jpe?g|png|gif|webp|bmp|tiff?|heic|heif|avif|svg|ico)$/i;

const fileFilter = (_req, file, cb) => {
  const okMime = /^image\//i.test(file.mimetype || '');
  const okExt = IMAGE_EXTS.test(file.originalname || '');
  if (!okMime && !okExt) {
    return cb(new Error('Only image files are allowed'));
  }
  cb(null, true);
};

const maxMb = Number(process.env.MAX_UPLOAD_MB || 10);

module.exports = multer({
  storage,
  fileFilter,
  limits: { fileSize: maxMb * 1024 * 1024 },
});
