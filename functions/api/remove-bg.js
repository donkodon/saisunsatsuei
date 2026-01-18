// Cloudflare Pages Functions: /api/remove-bg
// https://developers.cloudflare.com/pages/functions/

export async function onRequestPost(context) {
  const { request, env } = context;
  
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
  
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
    
    // Data URLの処理
    if (imageUrl.startsWith('data:image/')) {
      const base64Data = imageUrl.split(',')[1];
      const binaryString = atob(base64Data);
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }
      imageBuffer = bytes;
    } else {
      const imageResponse = await fetch(imageUrl);
      if (!imageResponse.ok) {
        return Response.json({ 
          success: false, 
          error: 'Failed to fetch image from URL'
        }, { status: 400, headers: corsHeaders });
      }
      
      const arrayBuffer = await imageResponse.arrayBuffer();
      imageBuffer = new Uint8Array(arrayBuffer);
    }
    
    // Cloudflare AIを使用
    if (!env.AI) {
      return Response.json({ 
        success: false, 
        error: 'Cloudflare AI is not configured',
        message: 'AI binding is required for background removal. Please add AI binding in Pages settings.'
      }, { status: 500, headers: corsHeaders });
    }
    
    const aiResponse = await env.AI.run(
      '@cf/bytedance/stable-diffusion-xl-lightning',  // テスト用モデル
      {
        image: Array.from(imageBuffer)
      }
    );
    
    return new Response(aiResponse, {
      headers: {
        ...corsHeaders,
        'Content-Type': 'image/png'
      }
    });
    
  } catch (error) {
    console.error('Background removal error:', error);
    return Response.json({ 
      success: false, 
      error: 'Background removal failed',
      details: error.message,
      stack: error.stack
    }, { status: 500, headers: corsHeaders });
  }
}

export async function onRequestOptions() {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    }
  });
}
