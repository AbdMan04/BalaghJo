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
  } else if (process.env.NODE_ENV === 'production') {
    // Fail fast in production: without Cloudinary the API would write photos
    // to the local uploads/ dir, which is ephemeral on Render and wiped on
    // redeploy. Report submissions are refused (storePhoto throws) until a
    // CLOUDINARY_URL is set, so images are never silently lost.
    console.error(
      '[cloudinary] CRITICAL: CLOUDINARY_URL is not set in production. ' +
        'Photo submissions are disabled; photos would otherwise be written ' +
        'to the ephemeral disk and lost on the next redeploy.'
    );
  } else {
    console.log('[cloudinary] CLOUDINARY_URL not set; photos stored locally');
  }
} catch (err) {
  console.error('[cloudinary] init failed, photos stored locally:', err.message);
}

module.exports = { uploader };
