import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

interface VerificationRequest {
  mediaUrl: string;
  mediaType: 'image' | 'video';
  storageBucket: string;
  storagePath: string;
  uploaderId: string;
}

interface AIVerificationResult {
  isAuthentic: boolean;
  confidenceScore: number;
  aiProvider: string;
  fullResponse: any;
  rejectionReason?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    const requestData: VerificationRequest = await req.json();
    const { mediaUrl, mediaType, storageBucket, storagePath, uploaderId } = requestData;

    // Create initial verification record
    const { data: verificationRecord, error: createError } = await supabase
      .from('media_verification_records')
      .insert({
        media_url: mediaUrl,
        media_type: mediaType,
        storage_bucket: storageBucket,
        storage_path: storagePath,
        uploader_id: uploaderId,
        verification_status: 'processing',
      })
      .select()
      .single();

    if (createError) throw createError;

    // Perform AI verification
    const aiResult = await performAIVerification(mediaUrl, mediaType);

    // Determine final status based on confidence score
    let finalStatus: 'verified' | 'suspicious' | 'rejected' = 'verified';
    
    if (aiResult.confidenceScore < 50) {
      finalStatus = 'rejected';
    } else if (aiResult.confidenceScore < 75) {
      finalStatus = 'suspicious';
    }

    // Update verification record with results
    const { error: updateError } = await supabase
      .from('media_verification_records')
      .update({
        verification_status: finalStatus,
        confidence_score: aiResult.confidenceScore,
        ai_provider: aiResult.aiProvider,
        ai_response: aiResult.fullResponse,
        rejection_reason: aiResult.rejectionReason,
        verified_at: finalStatus === 'verified' ? new Date().toISOString() : null,
      })
      .eq('id', verificationRecord.id);

    if (updateError) throw updateError;

    // Send notification to user about verification result
    if (finalStatus === 'rejected' || finalStatus === 'suspicious') {
      await supabase.from('notifications').insert({
        user_id: uploaderId,
        type: 'verification_result',
        title: finalStatus === 'rejected' ? 'Media Verification Failed' : 'Media Flagged for Review',
        message: aiResult.rejectionReason || 'Your uploaded media has been flagged by our AI verification system.',
        data: { verification_id: verificationRecord.id },
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        verificationId: verificationRecord.id,
        status: finalStatus,
        confidenceScore: aiResult.confidenceScore,
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Error verifying media:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});

/**
 * Performs AI-based verification of media authenticity
 * 
 * NOTE: This is a placeholder implementation that simulates AI verification.
 * In production, you should integrate with actual AI services like:
 * - Reality Defender API (https://www.realitydefender.com/platform/api)
 * - Sensity AI (https://sensity.ai/)
 * - Arya.ai Deepfake Detection (https://arya.ai/apex-apis/deepfake-detection-api)
 * - Sightengine (https://sightengine.com/detect-deepfakes)
 * 
 * Integration steps:
 * 1. Sign up for an AI verification service
 * 2. Add API key to Supabase Edge Function secrets
 * 3. Replace this function with actual API calls
 * 4. Parse the AI service response and map to our format
 */
async function performAIVerification(
  mediaUrl: string,
  mediaType: 'image' | 'video'
): Promise<AIVerificationResult> {
  // Simulate API call delay
  await new Promise(resolve => setTimeout(resolve, 1000));

  // PLACEHOLDER: Simulate AI analysis with random confidence score
  // In production, this would call an actual AI service
  
  // For demonstration, generate a random confidence score
  // Most media will pass (85-95%), some will be suspicious (65-75%), few will fail (30-50%)
  const random = Math.random();
  let confidenceScore: number;
  let rejectionReason: string | undefined;

  if (random > 0.9) {
    // 10% chance of suspicious
    confidenceScore = 65 + Math.random() * 10;
    rejectionReason = 'AI detected potential manipulation in facial features or lighting inconsistencies';
  } else if (random > 0.95) {
    // 5% chance of rejection
    confidenceScore = 30 + Math.random() * 20;
    rejectionReason = 'AI detected high probability of synthetic generation or deepfake manipulation';
  } else {
    // 85% chance of passing
    confidenceScore = 85 + Math.random() * 10;
  }

  return {
    isAuthentic: confidenceScore >= 75,
    confidenceScore: Math.round(confidenceScore * 100) / 100,
    aiProvider: 'placeholder-ai-service',
    fullResponse: {
      analyzed_at: new Date().toISOString(),
      media_type: mediaType,
      media_url: mediaUrl,
      confidence: confidenceScore,
      note: 'This is a simulated response. Replace with actual AI service integration.',
    },
    rejectionReason,
  };
}
