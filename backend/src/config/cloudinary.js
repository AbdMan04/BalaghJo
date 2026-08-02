/*
- Cloudinary image hosting (FR-5 / Phase 5 hardening). Optional: the API
- runs without Cloudinary until CLOUDINARY_URL is configured, and uploads
- then fall back to the local uploads/ directory.
- */
let uploader = null;

try {
  const cloudinaryUrl = process.env.CLOUDINARY_URL;
  if (cloudinaryUrl) {
    const cloudinary = require('cloudinary').v2;
    cloudinary.config({ cloudinary_url: cloudinaryUrl });
    uploader = cloudinary.uploader;
    console.log('[cloudinary] configured');
  } else {
    console.log('[cloudinary] CLOUDINARY_URL not set; photos stored locally');
  }
} catch (err) {
  console.error('[cloudinary] init failed, photos stored locally:', err.message);
}

module.exports = { uploader };
