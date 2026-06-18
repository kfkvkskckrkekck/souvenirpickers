import { supabase } from './supabase';

export async function getOrCreateConversation(clientId: string, pickerId: string): Promise<string> {
  const { data: existing, error: searchError } = await supabase
    .from('conversations')
    .select('id')
    .eq('client_id', clientId)
    .eq('picker_id', pickerId)
    .maybeSingle();

  if (searchError) throw searchError;

  if (existing) {
    return existing.id;
  }

  const { data: newConv, error: createError } = await supabase
    .from('conversations')
    .insert({
      client_id: clientId,
      picker_id: pickerId,
    })
    .select('id')
    .single();

  if (createError) throw createError;

  return newConv.id;
}
