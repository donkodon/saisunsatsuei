// Cloudflare Pages Functions Middleware
// This ensures Functions are properly loaded

export async function onRequest(context) {
  // Pass through to Functions
  return await context.next();
}
