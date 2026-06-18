import { supabase } from './supabase';

export async function sendEmailNotification(
  to: string,
  subject: string,
  type: 'order_confirmation' | 'order_shipped' | 'message_received' | 'wishlist_price_drop' | 'new_listing_match' | 'custom_order_response',
  data: any
) {
  try {
    const { data: response, error } = await supabase.functions.invoke('send-email-notification', {
      body: {
        to,
        subject,
        type,
        data
      }
    });

    if (error) {
      return { success: false, error };
    }

    return { success: true, data: response };
  } catch (error) {
    return { success: false, error };
  }
}

export async function notifyOrderConfirmation(customerEmail: string, customerName: string, orderId: string, itemTitle: string, totalAmount: number) {
  return sendEmailNotification(
    customerEmail,
    'Order Confirmation - SouvenirPickers',
    'order_confirmation',
    {
      customer_name: customerName,
      order_id: orderId,
      item_title: itemTitle,
      total_amount: totalAmount
    }
  );
}

export async function notifyOrderShipped(customerEmail: string, customerName: string, orderId: string, trackingNumber: string, estimatedDelivery: string) {
  return sendEmailNotification(
    customerEmail,
    'Your Order Has Shipped - SouvenirPickers',
    'order_shipped',
    {
      customer_name: customerName,
      order_id: orderId,
      tracking_number: trackingNumber,
      estimated_delivery: estimatedDelivery
    }
  );
}

export async function notifyNewMessage(recipientEmail: string, recipientName: string, senderName: string, messagePreview: string) {
  return sendEmailNotification(
    recipientEmail,
    `New Message from ${senderName} - SouvenirPickers`,
    'message_received',
    {
      recipient_name: recipientName,
      sender_name: senderName,
      message_preview: messagePreview
    }
  );
}

export async function notifyWishlistPriceDrop(userEmail: string, userName: string, itemTitle: string, listingId: string, oldPrice: number, newPrice: number) {
  return sendEmailNotification(
    userEmail,
    'Price Drop Alert - SouvenirPickers',
    'wishlist_price_drop',
    {
      user_name: userName,
      item_title: itemTitle,
      listing_id: listingId,
      old_price: oldPrice,
      new_price: newPrice
    }
  );
}

export async function notifyNewListingMatch(userEmail: string, userName: string, itemTitle: string, itemDescription: string, location: string, price: number, listingId: string) {
  return sendEmailNotification(
    userEmail,
    'New Souvenir Match - SouvenirPickers',
    'new_listing_match',
    {
      user_name: userName,
      item_title: itemTitle,
      item_description: itemDescription,
      location: location,
      price: price,
      listing_id: listingId
    }
  );
}

export async function notifyCustomOrderResponse(customerEmail: string, customerName: string, pickerName: string, requestTitle: string, offeredPrice: number, message: string) {
  return sendEmailNotification(
    customerEmail,
    'Response to Your Custom Order Request - SouvenirPickers',
    'custom_order_response',
    {
      customer_name: customerName,
      picker_name: pickerName,
      request_title: requestTitle,
      offered_price: offeredPrice,
      message: message
    }
  );
}
