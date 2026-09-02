/*
- Cloudinary helpers shared across the codebase. The publicId extraction
- regex was duplicated in reportController.js and config/db.js; this is
  the single source of truth.
 */
function publicIdFromUrl(url) {
  const m = String(url).match(/\/image\/upload\/(?:v\d+\/)?(.+)$/);
  return m ? m[1].replace(/\.[a-z0-9]+$/i, '') : null;
}

module.exports = { publicIdFromUrl };