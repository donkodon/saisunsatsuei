// Cloudflare Workers API with External Background Removal Service
// 外部APIを使用した背景削除（Remove.bg API使用）

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    
    // CORS設定
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-Api-Key',
    };
    
    // OPTIONSリクエスト
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // ================================================
    // 🎨 背景削除API (外部APIバージョン)
    // ================================================
    if (path === '/api/remove-bg' && request.method === 'POST') {
      try {
        const formData = await request.formData();
        const imageUrl = formData.get('imageUrl');
        
        if (!imageUrl) {
          return Response.json({ 
            success: false, 
            error: 'imageUrl is required' 
          }, { status: 400, headers: corsHeaders });
        }
        
        let imageBuffer;
        
        // Data URLかHTTP URLかを判定
        if (imageUrl.startsWith('data:image/')) {
          // Data URLの場合、Base64デコード
          const base64Data = imageUrl.split(',')[1];
          const binaryString = atob(base64Data);
          const bytes = new Uint8Array(binaryString.length);
          for (let i = 0; i < binaryString.length; i++) {
            bytes[i] = binaryString.charCodeAt(i);
          }
          imageBuffer = bytes.buffer;
        } else {
          // HTTP URLの場合、画像をダウンロード
          const imageResponse = await fetch(imageUrl);
          if (!imageResponse.ok) {
            return Response.json({ 
              success: false, 
              error: 'Failed to fetch image from URL'
            }, { status: 400, headers: corsHeaders });
          }
          
          imageBuffer = await imageResponse.arrayBuffer();
        }
        
        // Remove.bg APIを使用（APIキーが必要）
        // env.REMOVEBG_API_KEY に設定されている必要があります
        if (env.REMOVEBG_API_KEY) {
          const removeBgResponse = await fetch('https://api.remove.bg/v1.0/removebg', {
            method: 'POST',
            headers: {
              'X-Api-Key': env.REMOVEBG_API_KEY,
            },
            body: (() => {
              const fd = new FormData();
              fd.append('image_file', new Blob([imageBuffer]));
              fd.append('size', 'auto');
              return fd;
            })()
          });
          
          if (removeBgResponse.ok) {
            const resultBuffer = await removeBgResponse.arrayBuffer();
            return new Response(resultBuffer, {
              headers: {
                ...corsHeaders,
                'Content-Type': 'image/png'
              }
            });
          }
        }
        
        // APIキーがない場合、またはCloudflare AIを使用
        if (env.AI) {
          const aiResponse = await env.AI.run(
            '@cf/remove-bg/rembg-v1.4',
            {
              image: Array.from(new Uint8Array(imageBuffer))
            }
          );
          
          return new Response(aiResponse, {
            headers: {
              ...corsHeaders,
              'Content-Type': 'image/png'
            }
          });
        }
        
        // どちらも利用できない場合
        return Response.json({ 
          success: false, 
          error: 'Background removal service not configured',
          message: 'Please configure either REMOVEBG_API_KEY or Cloudflare AI binding'
        }, { status: 500, headers: corsHeaders });
        
      } catch (error) {
        console.error('Background removal error:', error);
        return Response.json({ 
          success: false, 
          error: 'Background removal failed',
          details: error.message
        }, { status: 500, headers: corsHeaders });
      }
    }
    
    // ================================================
    // ❌ 404 Not Found
    // ================================================
    return Response.json({ 
      success: false, 
      error: 'Not Found',
      path: path,
      method: request.method
    }, { 
      status: 404, 
      headers: corsHeaders 
    });
  }
};
